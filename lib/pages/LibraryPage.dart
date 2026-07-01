/// ライブラリタブ。
///
/// - お気に入りの本を横スクロール
/// - タグごとに本を横スクロールで直接表示（従来はタップで別画面だったが、
///   本が付いてるタグの本を Library でそのまま覗ける）
/// - 本がまだ 1 冊も付いていないタグは末尾の管理リストに集約
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../detail/BookDetail.dart';
import '../list/BookListItem.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../providers/custom_tags_provider.dart';
import '../services/tag_calculator.dart';
import '../theme/app_theme.dart';
import 'TagBooksPage.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final favorites = books.where((b) => b.isFavorite).toList();
    final usedTags = collectAllTags(books);
    final customTags = ref.watch(customTagsProvider);

    // 本に紐付くタグ + 0 冊の定義済みタグをマージ。
    // 冊数の多い順 → 同点はタグ名昇順で安定化（0 冊タグは末尾）。
    final usedTagsByName = {for (final t in usedTags) t.name: t.count};
    final allTagNames = <String>{...usedTagsByName.keys, ...customTags};
    final tags = allTagNames
        .map((name) =>
            TagCount(name: name, count: usedTagsByName[name] ?? 0))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.name.compareTo(b.name);
      });

    final activeTags = tags.where((t) => t.count > 0).toList();
    final emptyTags = tags.where((t) => t.count == 0).toList();
    final showEmptyState = favorites.isEmpty && tags.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ライブラリ'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _favoritesSection(context, favorites),
          // お気に入り ↔ タグ の区切り。
          if (activeTags.isNotEmpty || emptyTags.isNotEmpty) _divider(),
          if (activeTags.isNotEmpty || emptyTags.isNotEmpty)
            _sectionHeader(
              icon: Icons.local_offer_outlined,
              iconColor: AppColors.accent,
              title: 'タグ付けした本',
              count:
                  activeTags.isEmpty ? null : activeTags.length,
              trailing: _newTagButton(context, ref),
            ),
          if (activeTags.isNotEmpty)
            // 各タグは区切り線なしで連続表示。
            for (final tag in activeTags)
              ..._tagSubSection(context, ref, tag, books),
          if (emptyTags.isNotEmpty) ...[
            if (activeTags.isNotEmpty) _divider(),
            _emptyTagsList(context, emptyTags),
          ],
          if (showEmptyState) _emptyState(),
        ],
      ),
    );
  }

  /// セクション間の細い区切り線 (ホームと同じ style)。
  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(height: 1, color: AppColors.border),
    );
  }

  // ── セクション見出し (accent アイコン + タイトル + 副題) ──
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
    String? subtitle,
    int? count,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 15, color: iconColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fg,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '($count)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedFg,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 23),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedFg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── お気に入りセクション ─────────────────────────────
  Widget _favoritesSection(BuildContext context, List<Book> favorites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.favorite,
          iconColor: AppColors.favoritePink,
          title: 'お気に入りの本',
          count: favorites.isEmpty ? null : favorites.length,
        ),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'まだお気に入りに登録された本はありません',
              style: TextStyle(color: AppColors.mutedFg, fontSize: 13),
            ),
          )
        else
          _horizontalBooks(context, favorites),
      ],
    );
  }

  // ── 「タグ付けした本」配下の 1 タグ分（小見出し + 横スクロール） ─
  List<Widget> _tagSubSection(BuildContext context, WidgetRef ref,
      TagCount tag, List<Book> allBooks) {
    final books =
        allBooks.where((b) => b.tags.contains(tag.name)).toList();
    return [
      _tagSubHeader(context, ref, tag),
      _horizontalBooks(context, books),
    ];
  }

  Widget _tagSubHeader(BuildContext context, WidgetRef ref, TagCount tag) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 8, 6),
      child: Row(
        children: [
          Text(
            '#${tag.name}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.fg,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${tag.count})',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedFg,
            ),
          ),
          const SizedBox(width: 6),
          // 編集ボタン: タップで「リネーム / 削除」のポップアップメニュー。
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.mutedFg),
            tooltip: 'タグを編集',
            padding: EdgeInsets.zero,
            iconSize: 16,
            splashRadius: 18,
            position: PopupMenuPosition.under,
            color: AppColors.bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            onSelected: (v) {
              if (v == 'rename') _renameTag(context, ref, tag.name);
              if (v == 'delete') {
                _deleteTag(context, ref, tag.name, tag.count);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        size: 16, color: AppColors.mutedFg),
                    SizedBox(width: 10),
                    Text('リネーム',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.fg)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        size: 16, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('削除',
                        style: TextStyle(
                            fontSize: 13, color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Text(
              'すべて',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            label: const Icon(Icons.chevron_right, size: 16),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TagBooksPage(tag: tag.name)),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _renameTag(
      BuildContext context, WidgetRef ref, String oldName) async {
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
    await ref.read(bookListProvider.notifier).renameTag(oldName, newName);
    await ref.read(customTagsProvider.notifier).renameTag(oldName, newName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$oldName」を「$newName」にリネームしました')),
    );
  }

  Future<void> _deleteTag(
      BuildContext context, WidgetRef ref, String tag, int count) async {
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

  // ── 「新規タグ」ボタン（タグ付けした本 見出しの右端） ─────
  Widget _newTagButton(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppColors.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      icon: const Icon(Icons.add, size: 14),
      label: const Text(
        '新規タグ',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      onPressed: () => _showCreateTagSheet(context, ref),
    );
  }

  /// 新規タグ作成ダイアログ (画面中央、自由入力 + テンプレートから追加)。
  Future<void> _showCreateTagSheet(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _CreateTagSheet(),
        ),
      ),
    );
  }

  // ── 横スクロール共通ウィジェット ─────────────────────
  Widget _horizontalBooks(BuildContext context, List<Book> books) {
    return SizedBox(
      height: 230,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: 145,
              child: BookListItem(
                book: book,
                compact: true,
                showActionButton: false,
                showRating: false,
                showStatusBadge: false,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => BookDetail(book: book)),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 0 冊タグの管理リスト（末尾に集約） ────────────────
  Widget _emptyTagsList(BuildContext context, List<TagCount> emptyTags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.label_outline,
          iconColor: AppColors.mutedFg,
          title: '本がまだ付いていないタグ',
          subtitle: '本詳細の「+ タグを追加」から本に付けられます',
          count: emptyTags.length,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emptyTags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '#${t.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedFg,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── お気に入りもタグも 0 のときの案内 ─────────────
  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          '本詳細から♥ボタンを押す、もしくはタグを付けると、\nここに集約されます',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedFg),
        ),
      ),
    );
  }
}

/// 新規タグ作成用のボトムシート。
/// テキスト入力で自由に作成 + テンプレートから 1 タップ追加できる。
class _CreateTagSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<_CreateTagSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await ref.read(customTagsProvider.notifier).addTag(trimmed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$trimmed」を追加しました')),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final customTags = ref.watch(customTagsProvider);
    final usedTagNames =
        collectAllTags(books).map((t) => t.name).toSet();
    final existing = <String>{...usedTagNames, ...customTags};
    final templates = buildTagTemplates(DateTime.now());

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '新規タグ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '自由に入力するか、下のテンプレートから追加できます。',
              style: TextStyle(fontSize: 12, color: AppColors.mutedFg),
            ),
            const SizedBox(height: 16),
            // 自由入力
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '例: 仕事用',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _create,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryFg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => _create(_controller.text),
                  child: const Text('作成'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // テンプレート
            const Text(
              'テンプレートから追加',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedFg,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: templates.map((tag) {
                final exists = existing.contains(tag);
                return InkWell(
                  onTap: exists ? null : () => _create(tag),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: exists
                          ? AppColors.secondary.withValues(alpha: 0.4)
                          : AppColors.secondary,
                      borderRadius: BorderRadius.circular(999),
                      border: exists
                          ? Border.all(color: AppColors.border)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          exists ? Icons.check : Icons.add,
                          size: 12,
                          color: exists
                              ? AppColors.mutedFg
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: exists
                                ? AppColors.mutedFg
                                : AppColors.fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
