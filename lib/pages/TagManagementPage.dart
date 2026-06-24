/// タグ管理画面（W12 で新規追加）。
///
/// ライブラリタブの AppBar ⚙️ アイコンから遷移する画面。
/// - 全タグ一覧 + 各タグの本の冊数
///   - 本に紐付くタグ（Book.tags から集計）
///   - 定義済みタグ（customTagsProvider、まだ本に付いていない 0 冊タグも含む）
///   - 両者を合算した一覧で表示（同名はマージ、冊数だけ更新）
/// - 「+ 新規タグ」ボタンでタグ名を入力 → 定義済みタグに保存
///   → 本詳細のタグ編集ダイアログにも候補として現れる
/// - 各タグをリネーム / 削除（リネーム時は本に紐付くタグと定義済みタグ両方
///   を一括更新、削除も同じ）
/// - 「テンプレート」のサブセクションでよく使う名前を 1 タップで作成
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/book_list_provider.dart';
import '../providers/custom_tags_provider.dart';
import '../services/tag_calculator.dart';
import 'TagBooksPage.dart';

class TagManagementPage extends ConsumerWidget {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final usedTags = collectAllTags(books);
    final customTags = ref.watch(customTagsProvider);
    final templates = buildTagTemplates(DateTime.now());

    // 本に紐付くタグ + 定義済みタグ をマージして表示。
    // 冊数は本に紐付くタグ側の集計を優先（0 冊ならカスタム由来）。
    final usedTagsByName = {for (final t in usedTags) t.name: t.count};
    final allTagNames = <String>{...usedTagsByName.keys, ...customTags};
    final mergedTags = allTagNames
        .map((name) =>
            TagCount(name: name, count: usedTagsByName[name] ?? 0))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('タグ管理'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTagDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新規タグ'),
      ),
      body: ListView(
        children: [
          if (mergedTags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'まだタグがありません。右下の「+ 新規タグ」から作成、または本詳細の「+ タグを追加」から付けられます',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ...mergedTags.map((t) => ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(t.name),
                  subtitle: Text(
                    t.count > 0 ? '${t.count} 冊' : '0 冊（まだ本に付いていません）',
                    style: TextStyle(
                      color: t.count > 0 ? null : Colors.black45,
                    ),
                  ),
                  onTap: t.count > 0
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TagBooksPage(tag: t.name),
                            ),
                          );
                        }
                      : null,
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'rename') {
                        await _renameTag(context, ref, t.name);
                      } else if (v == 'delete') {
                        await _deleteTag(context, ref, t.name, t.count);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('リネーム')),
                      PopupMenuItem(value: 'delete', child: Text('削除')),
                    ],
                  ),
                )),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: const [
                Icon(Icons.bookmark_added_outlined, size: 18),
                SizedBox(width: 6),
                Text(
                  'テンプレート',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'タップでタグを作成します（本詳細のタグ編集にも候補として表示されます）',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: templates.map((tag) {
                final exists = allTagNames.contains(tag);
                return ActionChip(
                  avatar: Icon(
                    exists ? Icons.check_circle : Icons.add_circle_outline,
                    size: 14,
                    color: exists ? Colors.green : null,
                  ),
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  onPressed: exists
                      ? null
                      : () async {
                          await ref
                              .read(customTagsProvider.notifier)
                              .addTag(tag);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('「$tag」を追加しました')),
                          );
                        },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 「+ 新規タグ」ボタンから開くタグ作成ダイアログ。
  Future<void> _showCreateTagDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規タグを作成'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例: 仕事用',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    await ref.read(customTagsProvider.notifier).addTag(newName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$newName」を作成しました')),
    );
  }

  Future<void> _renameTag(
    BuildContext context,
    WidgetRef ref,
    String oldName,
  ) async {
    final controller = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「$oldName」をリネーム'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == oldName) return;
    // 本に紐付くタグも、定義済みタグ側も両方リネーム
    await ref.read(bookListProvider.notifier).renameTag(oldName, newName);
    await ref.read(customTagsProvider.notifier).renameTag(oldName, newName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$oldName」を「$newName」にリネームしました')),
    );
  }

  Future<void> _deleteTag(
    BuildContext context,
    WidgetRef ref,
    String tag,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('「$tag」を削除'),
        content: Text(
          count > 0
              ? '$count 冊の本からこのタグを外します。本自体は残ります。'
              : 'このタグを削除します（まだ本に付いていません）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(bookListProvider.notifier).removeTagFromAllBooks(tag);
    await ref.read(customTagsProvider.notifier).removeTag(tag);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$tag」を削除しました')),
    );
  }
}
