/// 本の詳細ページ。
///
/// W4: Stack モーダル → Navigator.push の独立ページに進化、Hero アニメ追加
/// W5: 編集 UI を追加
///   - ChoiceChip でステータス変更（読みたい / 読書中 / 読了）
///   - flutter_rating_bar で ★評価（5 段階）
///   - TextField で進捗（currentPage）の編集
///   - レビュー一覧 + 「+ 追加」ボタン（ReviewEditPage へ Navigator.push）
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/pages/ReviewEditPage.dart';
import '../models/book.dart';
import '../models/review.dart';
import '../providers/book_list_provider.dart';
import '../providers/custom_tags_provider.dart';
import '../providers/review_list_provider.dart';
import '../services/tag_calculator.dart';

class BookDetail extends ConsumerStatefulWidget {
  final Book book;

  const BookDetail({super.key, required this.book});

  @override
  ConsumerState<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends ConsumerState<BookDetail> {
  late final TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController(
      text: widget.book.currentPage.toString(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _statusLabel(BookStatus s) {
    switch (s) {
      case BookStatus.wantToRead:
        return '読みたい';
      case BookStatus.reading:
        return '読書中';
      case BookStatus.finished:
        return '読了';
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  /// 「本棚から削除」フロー（W4 で追加）。
  Future<void> _confirmAndRemove(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本棚から削除'),
        content: Text('「${book.title}」を本棚から削除しますか？'),
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
    if (!mounted) return;

    // W9 fix: 削除 → provider 更新 → build の自動 pop ロジック発火 →
    // 加えてここでも pop → 二重 pop で IndexedStack ごと突き抜けて
    // 真っ黒画面になる不具合があった。
    // 解決策: pop を先に行い、ウィジェットを unmount してから provider を
    // 更新する。NavigatorState / ScaffoldMessenger は pop 前に確保しておく。
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final title = book.title;

    navigator.pop();
    await ref.read(bookListProvider.notifier).remove(book.id);

    messenger.showSnackBar(
      SnackBar(content: Text('「$title」を本棚から削除しました')),
    );
  }

  /// 進捗の TextField から数字を読み取って provider に保存（W5）。
  Future<void> _saveProgress(Book book) async {
    final input = int.tryParse(_pageController.text);
    if (input == null) return;
    final clamped = input.clamp(0, book.totalPages ?? input);
    await ref.read(bookListProvider.notifier).updateProgress(book.id, clamped);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('進捗を $clamped ページに更新しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // bookListProvider を watch して、最新の Book を取得する。
    final books = ref.watch(bookListProvider);
    final book = books.where((b) => b.id == widget.book.id).firstOrNull;

    if (book == null) {
      // 本がもう存在しない（削除フロー中 / 外部要因で消えた）。
      // 注意: W9 まで「自動で Navigator.pop」していたが、削除フローでも
      // 明示的に pop しているため二重 pop で IndexedStack の外まで突き抜けて
      // 真っ黒画面になっていた。空 Scaffold だけ返して、pop は呼び出し元
      // （_confirmAndRemove）に任せる。
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('本の詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '本棚から削除',
            onPressed: () => _confirmAndRemove(book),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _coverImage(book)),
            const SizedBox(height: 16),
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${book.author}${book.publisher != null ? "（${book.publisher}）" : ""}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            if (book.genre != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.label_outline,
                      size: 14, color: Colors.black45),
                  const SizedBox(width: 4),
                  Text(
                    book.genre!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            _tagsSection(book), // W12: タグ表示 + 編集
            const SizedBox(height: 20),
            _statusEditor(book),
            const SizedBox(height: 16),
            _ratingEditor(book),
            const SizedBox(height: 16),
            if (book.totalPages != null) _progressEditor(book),
            const SizedBox(height: 16),
            _dateInfo(book),
            const SizedBox(height: 24),
            _reviewSection(book),
          ],
        ),
      ),
    );
  }

  Widget _coverImage(Book book) {
    final url = book.coverImageUrl;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = Container(
        width: 160,
        height: 220,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book_outlined, size: 80, color: Colors.black54),
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        height: 220,
        fit: BoxFit.contain,
        placeholder: (context, url) => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 160,
          height: 220,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    return Hero(
      tag: 'cover-${book.id}',
      child: image,
    );
  }

  /// タグ表示 + 編集ボタン（W12）。
  /// タグなしの本では「+ タグを追加」リンクだけを出す。
  Widget _tagsSection(Book book) {
    if (book.tags.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.local_offer_outlined,
              size: 14, color: Colors.black45),
          const SizedBox(width: 4),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openTagEditor(book),
            child: const Text('+ タグを追加',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.local_offer_outlined,
            size: 14, color: Colors.black45),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: book.tags
                .map((t) => Chip(
                      label: Text('#$t', style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ),
        IconButton(
          tooltip: 'タグを編集',
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: () => _openTagEditor(book),
        ),
      ],
    );
  }

  /// タグ編集ダイアログを開く（W12）。
  /// 既存のタグ（本棚全体から集計）から複数選択 + 新規タグ作成 + テンプレート
  /// から追加、ができる。OK で book.tags を保存。
  Future<void> _openTagEditor(Book book) async {
    final allBooks = ref.read(bookListProvider);
    final customTags = ref.read(customTagsProvider);
    // 本に紐付くタグと、ユーザーが定義済みのタグ（タグ管理画面で「+ 新規」
    // した分）の両方を候補にする。これで「タグ管理で作って → 本詳細で
    // 選んで付与」の流れが完結する。
    final availableTags = <String>{
      ...collectAllTags(allBooks).map((t) => t.name),
      ...customTags,
    };
    final templates = buildTagTemplates(DateTime.now());

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => _TagEditorDialog(
        initialTags: book.tags,
        availableTags: availableTags,
        templates: templates,
      ),
    );

    if (result != null) {
      await ref.read(bookListProvider.notifier).updateTags(book.id, result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タグを更新しました')),
      );
    }
  }

  Widget _statusEditor(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ステータス',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: BookStatus.values.map((s) {
            final selected = book.status == s;
            return ChoiceChip(
              label: Text(_statusLabel(s)),
              selected: selected,
              onSelected: (_) {
                if (!selected) {
                  ref
                      .read(bookListProvider.notifier)
                      .updateStatus(book.id, s);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _ratingEditor(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '評価',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            RatingBar.builder(
              initialRating: book.rating,
              minRating: 0,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 32,
              itemPadding: const EdgeInsets.symmetric(horizontal: 2),
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                ref
                    .read(bookListProvider.notifier)
                    .updateRating(book.id, rating);
              },
            ),
            const SizedBox(width: 8),
            Text(
              book.rating > 0
                  ? '${book.rating.toStringAsFixed(1)} / 5.0'
                  : '未評価',
              style: const TextStyle(color: Colors.black54),
            ),
            const Spacer(),
            // W11: お気に入り本スイッチ。♥アイコンで「本そのもの」を mark する。
            // 本棚カードの右上 ♥ マーク、本棚の「♡だけ」フィルタ、ホームタブの
            // 「お気に入りの本」セクションに反映される。
            Tooltip(
              message: book.isFavorite
                  ? 'お気に入りから外す'
                  : 'この本をお気に入りに追加',
              child: IconButton(
                icon: Icon(
                  book.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: book.isFavorite ? Colors.pink : Colors.black45,
                ),
                onPressed: () {
                  ref
                      .read(bookListProvider.notifier)
                      .toggleFavorite(book.id);
                },
              ),
            ),
            // W9: お気に入り著者スイッチ。person アイコンで「著者」を mark する。
            // ON にすると、この本の主著者が「お気に入り著者」として統計画面・
            // ホームタブのおすすめに登場する。
            // W11 で本のお気に入り♥と並ぶため、アイコンを person 系に変更。
            Tooltip(
              message: book.isFavoriteAuthor
                  ? 'お気に入り著者を解除'
                  : 'この著者をお気に入りにする',
              child: IconButton(
                icon: Icon(
                  book.isFavoriteAuthor
                      ? Icons.person
                      : Icons.person_outline,
                  color: book.isFavoriteAuthor ? Colors.pink : Colors.black45,
                ),
                onPressed: () {
                  ref
                      .read(bookListProvider.notifier)
                      .toggleFavoriteAuthor(book.id);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _progressEditor(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '進捗',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('/ ${book.totalPages} ページ'),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _saveProgress(book),
              child: const Text('更新'),
            ),
          ],
        ),
      ],
    );
  }

  /// 状態に応じた日付情報セクション（W9 で編集可能化）。
  ///
  /// - 読みたい: 「本棚に追加」（addedAt 編集可）
  /// - 読書中:   「読み始め」（startedAt 編集可）
  /// - 読了:     「読み始め」「読了」（両方編集可）
  ///
  /// 値が null の場合は「未設定」表示にして、編集ボタンから後付けで日付を
  /// 設定できる（W9 以前に登録した本でも addedAt を入れたい・リマインダーを
  /// テストしたい等のケースに対応）。
  Widget _dateInfo(Book book) {
    final rows = <Widget>[];

    switch (book.status) {
      case BookStatus.wantToRead:
        rows.add(_editableDateRow(
          label: '本棚に追加',
          date: book.addedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateAddedAt(book.id, d),
        ));
        break;
      case BookStatus.reading:
        rows.add(_editableDateRow(
          label: '読み始め',
          date: book.startedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateStartedAt(book.id, d),
        ));
        break;
      case BookStatus.finished:
        rows.add(_editableDateRow(
          label: '読み始め',
          date: book.startedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateStartedAt(book.id, d),
        ));
        rows.add(_editableDateRow(
          label: '読了',
          date: book.finishedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateFinishedAt(book.id, d),
        ));
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  /// 日付編集 1 行: 「ラベル: yyyy/MM/dd」 + カレンダーアイコン。
  /// [date] が null の場合は「未設定」表示、初期日付は今日を提示する。
  Widget _editableDateRow({
    required String label,
    required DateTime? date,
    required Future<void> Function(DateTime) onChanged,
  }) {
    final hasDate = date != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            hasDate ? '$label: ${_formatDate(date)}' : '$label: 未設定',
            style: hasDate
                ? null
                : const TextStyle(color: Colors.black54),
          ),
        ),
        IconButton(
          tooltip: '$label を編集',
          icon: const Icon(Icons.edit_calendar_outlined, size: 20),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              helpText: '$label を選択',
            );
            if (picked != null) {
              await onChanged(picked);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label を ${_formatDate(picked)} に更新しました')),
              );
            }
          },
        ),
      ],
    );
  }

  /// レビュー一覧 + 「追加」ボタン（W5 コミット 5 で追加）。
  Widget _reviewSection(Book book) {
    final reviews = ref.watch(reviewListProvider(book.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'レビュー',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text('(${reviews.length})',
                style: const TextStyle(color: Colors.black54)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('追加'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewEditPage(bookId: book.id),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'まだレビューがありません',
              style: TextStyle(color: Colors.black45),
            ),
          )
        else
          ...reviews.map((r) => _reviewTile(book.id, r)),
      ],
    );
  }

  Widget _reviewTile(String bookId, Review review) {
    return Card(
      child: ListTile(
        title: Text(
          review.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          review.updatedAt != null
              ? '更新: ${_formatDate(review.updatedAt!)}'
              : '作成: ${_formatDate(review.createdAt)}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReviewEditPage(bookId: bookId, existingReview: review),
            ),
          );
        },
      ),
    );
  }
}

/// 本詳細で開くタグ編集ダイアログ（W12 で追加）。
///
/// - 既存のタグ（本棚全体から集計）を FilterChip で複数選択できる
/// - 「+ 新規タグ」テキストフィールドで自由入力
/// - 「テンプレートから追加」サブセクションで定義済みプリセットを 1 タップ
/// - 「保存」で選択タグの最終リストを返す（Navigator.pop の戻り値）
class _TagEditorDialog extends StatefulWidget {
  final List<String> initialTags;
  final Set<String> availableTags;
  final List<String> templates;

  const _TagEditorDialog({
    required this.initialTags,
    required this.availableTags,
    required this.templates,
  });

  @override
  State<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<_TagEditorDialog> {
  late Set<String> _selected;
  final _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTags.toSet();
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
  }

  void _addNewTag() {
    final t = _newTagController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _selected.add(t);
      _newTagController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 既存タグ + 選択中の新規タグ を合わせて FilterChip 化する候補。
    final allCandidates = <String>{...widget.availableTags, ..._selected};
    final sortedCandidates = allCandidates.toList()..sort();

    // テンプレートのうちまだ候補に無いもの（候補にあれば下の FilterChip と
    // 二重に出すのを避ける）。
    final templatesToShow = widget.templates
        .where((t) => !allCandidates.contains(t))
        .toList(growable: false);

    return AlertDialog(
      title: const Text('タグを編集'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sortedCandidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'まだタグがありません。下から新規作成してください',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: sortedCandidates.map((tag) {
                    final selected = _selected.contains(tag);
                    return FilterChip(
                      label: Text('#$tag'),
                      selected: selected,
                      onSelected: (_) => _toggleTag(tag),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
              const Text(
                '+ 新規タグ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      decoration: const InputDecoration(
                        hintText: '例: 仕事用',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addNewTag(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _addNewTag,
                    child: const Text('追加'),
                  ),
                ],
              ),
              if (templatesToShow.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'テンプレートから追加',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: templatesToShow.map((tag) {
                    return ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: Text(tag),
                      onPressed: () {
                        setState(() {
                          _selected.add(tag);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
