/// タグ管理画面（W12 で新規追加）。
///
/// ライブラリタブの AppBar ⚙️ アイコンから遷移する画面。
/// - 全タグ一覧 + 各タグの本の冊数
///   - 本に紐付くタグ（Book.tags から集計）
///   - 定義済みタグ（customTagsProvider、まだ本に付いていない 0 冊タグも含む）
///   - 両者を合算した一覧で表示（同名はマージ、冊数だけ更新）
/// - 各タグの右端に「リネーム」「削除」の IconButton を並べる
/// - 新規タグ作成 / テンプレートからの追加はライブラリ画面の「新規タグ」
///   ボタンに集約
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/book_list_provider.dart';
import '../providers/custom_tags_provider.dart';
import '../services/tag_calculator.dart';
import '../theme/app_theme.dart';
import 'TagBooksPage.dart';

class TagManagementPage extends ConsumerWidget {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final usedTags = collectAllTags(books);
    final customTags = ref.watch(customTagsProvider);

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
      body: mergedTags.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'まだタグがありません。\nライブラリの「新規タグ」ボタンから作成できます',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedFg),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: mergedTags.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final t = mergedTags[index];
                return _tagTile(context, ref, t);
              },
            ),
    );
  }

  Widget _tagTile(BuildContext context, WidgetRef ref, TagCount t) {
    return ListTile(
      leading: const Icon(Icons.tag, color: AppColors.accent),
      title: Text(
        t.name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.fg,
        ),
      ),
      subtitle: Text(
        t.count > 0 ? '${t.count} 冊' : '0 冊（まだ本に付いていません）',
        style: TextStyle(
          fontSize: 12,
          color: t.count > 0 ? AppColors.mutedFg : AppColors.mutedFg,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppColors.mutedFg,
            tooltip: 'リネーム',
            onPressed: () => _renameTag(context, ref, t.name),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.redAccent,
            tooltip: '削除',
            onPressed: () => _deleteTag(context, ref, t.name, t.count),
          ),
        ],
      ),
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
