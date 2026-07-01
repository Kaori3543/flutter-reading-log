/// 本の詳細ページ。
///
/// W4: Stack モーダル → Navigator.push の独立ページに進化、Hero アニメ追加
/// W5: 編集 UI を追加（ステータス / ★評価 / 進捗 / レビュー）
/// UI 改修: Figma 提供の warm brown パレット + 2 カラム構成に刷新。
///   - 上部にダーク茶の固定ヘッダー（戻る / タイトル / 削除）
///   - 左サイドはダーク茶グラデーション + カバー画像（3D perspective + 濃い影）
///   - 右メインは cream 背景 + セクション見出しは細字トラッキング広めの
///     muted テキスト、区切り線で 3 グループに分けて配置
library;

import 'dart:math' as math;

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
import '../theme/app_theme.dart';

class BookDetail extends ConsumerStatefulWidget {
  final Book book;

  const BookDetail({super.key, required this.book});

  @override
  ConsumerState<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends ConsumerState<BookDetail> {
  // ── パレット (AppColors エイリアス) ───────────────────
  static const Color _bg = AppColors.bg;
  static const Color _fg = AppColors.fg;
  static const Color _primary = AppColors.primary;
  static const Color _primaryFg = AppColors.primaryFg;
  static const Color _secondary = AppColors.secondary;
  static const Color _muted = AppColors.muted;
  static const Color _mutedFg = AppColors.mutedFg;
  static const Color _accent = AppColors.accent;
  static const Color _border = AppColors.border;
  static const Color _starIdle = AppColors.starIdle;
  static const Color _favoritePink = AppColors.favoritePink;
  static const Color _favoriteBg = AppColors.favoriteBg;
  static const Color _headerBg = AppColors.headerBg;
  static const Color _asideStart = AppColors.asideStart;
  static const Color _asideMid = AppColors.asideMid;
  static const Color _asideEnd = AppColors.asideEnd;

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

  String _formatDateJp(DateTime dt) => '${dt.year}年${dt.month}月${dt.day}日';

  /// 「本棚から削除」フロー。
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

    // 二重 pop 回避のため NavigatorState / Messenger を先に確保。
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final title = book.title;

    navigator.pop();
    await ref.read(bookListProvider.notifier).remove(book.id);

    messenger.showSnackBar(
      SnackBar(content: Text('「$title」を本棚から削除しました')),
    );
  }

  /// 進捗の TextField から数字を読み取って provider に保存。
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
    final books = ref.watch(bookListProvider);
    final book = books.where((b) => b.id == widget.book.id).firstOrNull;
    if (book == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _customHeader(book),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, cons) {
                  final isWide = cons.maxWidth >= 720;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _leftAside(book),
                        Expanded(child: _rightPaneScrollable(book)),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _coverWithShadow(book, tilt: false),
                        const SizedBox(height: 32),
                        _rightPaneContent(book),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 上部ヘッダー ─────────────────────────────────────────
  Widget _customHeader(Book book) {
    return Container(
      height: 56,
      color: _headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _headerButton(
            icon: Icons.arrow_back,
            label: 'ライブラリに戻る',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: Text(
                '本の詳細',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          _headerButton(
            icon: Icons.delete_outline,
            label: '削除',
            hoverColor: Colors.redAccent,
            onTap: () => _confirmAndRemove(book),
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? hoverColor,
  }) {
    final base = Colors.white.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: base),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: base,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 左サイド (dark gradient + cover) ─────────────────────
  Widget _leftAside(Book book) {
    return Container(
      width: 288,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.6, 1.0],
          colors: [_asideStart, _asideMid, _asideEnd],
        ),
        border: Border(
          right: BorderSide(color: Color(0x0FFFFFFF)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _coverWithShadow(book, tilt: true),
          ],
        ),
      ),
    );
  }

  // ── 右メイン (幅広時) ─────────────────────────────────
  Widget _rightPaneScrollable(Book book) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 768),
        child: _rightPaneContent(book),
      ),
    );
  }

  /// カバー: 3D perspective 回転 + 濃い影で「本らしく」浮かせる。
  Widget _coverWithShadow(
    Book book, {
    required bool tilt,
    double width = 160,
    double height = 230,
  }) {
    final image = _coverImageOnly(book, width: width, height: height);
    Widget shadowed = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 64,
            offset: const Offset(0, 24),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Hero(tag: 'cover-${book.id}', child: image),
      ),
    );
    if (tilt) {
      shadowed = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // perspective
          ..rotateY(-0.087), // -5deg
        child: shadowed,
      );
    }
    return shadowed;
  }

  Widget _coverImageOnly(Book book,
      {required double width, required double height}) {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book_outlined, size: 80, color: Colors.black54),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  /// 縦積みレイアウトの中身。ユーザー指定の順序: タイトル → タグ → 追加日 →
  /// ステータス → 評価 → 進捗 → レビュー。
  Widget _rightPaneContent(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleBlock(book),
        const SizedBox(height: 24),
        _tagsSection(book),
        const SizedBox(height: 32),
        _divider(),
        const SizedBox(height: 32),
        _dateSection(book),
        const SizedBox(height: 32),
        _statusSection(book),
        const SizedBox(height: 32),
        _ratingSection(book),
        if (book.totalPages != null) ...[
          const SizedBox(height: 32),
          _progressSection(book),
        ],
        const SizedBox(height: 32),
        _divider(),
        const SizedBox(height: 32),
        _reviewSection(book),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 1, width: double.infinity, color: _border);

  // ── セクション見出し (uppercase-tracking 風) ───────────
  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: _mutedFg,
      ),
    );
  }

  // ── タイトル + 著者 + ジャンル ─────────────────────────
  Widget _titleBlock(Book book) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: _fg,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${book.author}${book.publisher != null ? "（${book.publisher}）" : ""}',
          style: const TextStyle(fontSize: 13, color: _mutedFg),
        ),
        if (book.genre != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.label_outline, size: 13, color: _mutedFg),
              const SizedBox(width: 4),
              Text(
                book.genre!,
                style: const TextStyle(fontSize: 12, color: _mutedFg),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── タグ + お気に入り (♥ 本 / 👤 著者) ──────────────
  Widget _tagsSection(Book book) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.local_offer_outlined, size: 13, color: _mutedFg),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...book.tags.map((t) => _tagChip(t)),
              _addTagPill(book),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _circleAction(
          filled: book.isFavorite,
          icon: book.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: book.isFavorite ? _favoritePink : _mutedFg,
          bg: book.isFavorite ? _favoriteBg : _secondary,
          tooltip: book.isFavorite ? 'お気に入りから外す' : 'この本をお気に入りに追加',
          onTap: () =>
              ref.read(bookListProvider.notifier).toggleFavorite(book.id),
        ),
        const SizedBox(width: 8),
        _circleAction(
          filled: book.isFavoriteAuthor,
          icon: book.isFavoriteAuthor ? Icons.person : Icons.person_outline,
          color: book.isFavoriteAuthor ? _favoritePink : _mutedFg,
          bg: book.isFavoriteAuthor ? _favoriteBg : _secondary,
          tooltip: book.isFavoriteAuthor
              ? 'お気に入り著者を解除'
              : 'この著者をお気に入りにする',
          onTap: () => ref
              .read(bookListProvider.notifier)
              .toggleFavoriteAuthor(book.id),
        ),
      ],
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(fontSize: 11, color: _fg),
      ),
    );
  }

  Widget _addTagPill(Book book) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: _accent, radius: 999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _openTagEditor(book),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            book.tags.isEmpty ? '+ タグを追加' : '+ 追加',
            style: const TextStyle(
              fontSize: 12,
              color: _accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTagEditor(Book book) async {
    final allBooks = ref.read(bookListProvider);
    final customTags = ref.read(customTagsProvider);
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

  // ── ステータス ─────────────────────────────────────
  Widget _statusSection(Book book) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: BookStatus.values.map((s) => _statusChip(book, s)).toList(),
    );
  }

  Widget _statusChip(Book book, BookStatus s) {
    final selected = book.status == s;
    return InkWell(
      onTap: () {
        if (!selected) {
          ref.read(bookListProvider.notifier).updateStatus(book.id, s);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary : _secondary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          _statusLabel(s),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? _primaryFg : _mutedFg,
          ),
        ),
      ),
    );
  }

  Widget _circleAction({
    required bool filled,
    required IconData icon,
    required Color color,
    required Color bg,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

  // ── 追加日 ───────────────────────────────────────────
  Widget _dateSection(Book book) {
    final entries = <_DateEntry>[];
    switch (book.status) {
      case BookStatus.wantToRead:
        entries.add(_DateEntry(
          label: '追加日',
          date: book.addedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateAddedAt(book.id, d),
        ));
        break;
      case BookStatus.reading:
        entries.add(_DateEntry(
          label: '読み始め',
          date: book.startedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateStartedAt(book.id, d),
        ));
        break;
      case BookStatus.finished:
        entries.add(_DateEntry(
          label: '読み始め',
          date: book.startedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateStartedAt(book.id, d),
        ));
        entries.add(_DateEntry(
          label: '読了',
          date: book.finishedAt,
          onChanged: (d) async => ref
              .read(bookListProvider.notifier)
              .updateFinishedAt(book.id, d),
        ));
        break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(entries.length == 1 ? entries.first.label : '日付'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries.map(_dateChip).toList(),
        ),
      ],
    );
  }

  Widget _dateChip(_DateEntry entry) {
    final label = entry.date != null
        ? _formatDateJp(entry.date!)
        : '${entry.label} 未設定';
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: entry.date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: '${entry.label} を選択',
        );
        if (picked != null) {
          await entry.onChanged(picked);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${entry.label} を ${_formatDate(picked)} に更新しました')),
          );
        }
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: _mutedFg),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 評価 ──────────────────────────────────────────────
  Widget _ratingSection(Book book) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('評価'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            RatingBar.builder(
              initialRating: book.rating,
              minRating: 0,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemSize: 32,
              itemPadding: const EdgeInsets.symmetric(horizontal: 2),
              unratedColor: _starIdle,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: _accent),
              onRatingUpdate: (rating) {
                ref
                    .read(bookListProvider.notifier)
                    .updateRating(book.id, rating);
              },
            ),
            const SizedBox(width: 16),
            Text(
              book.rating > 0
                  ? '${book.rating.toStringAsFixed(1)} / 5'
                  : '未評価',
              style: const TextStyle(fontSize: 14, color: _mutedFg),
            ),
          ],
        ),
      ],
    );
  }

  // ── 進捗 ──────────────────────────────────────────────
  Widget _progressSection(Book book) {
    final total = book.totalPages ?? 0;
    final current = book.currentPage
        .clamp(0, total > 0 ? total : book.currentPage);
    final ratio = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('進捗'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: _muted,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _fg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
            Text('/ ${book.totalPages} ページ',
                style: const TextStyle(color: _mutedFg)),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _primaryFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () => _saveProgress(book),
              child: const Text('更新'),
            ),
          ],
        ),
      ],
    );
  }

  // ── レビュー ─────────────────────────────────────────
  Widget _reviewSection(Book book) {
    final reviews = ref.watch(reviewListProvider(book.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('レビュー  (${reviews.length})')),
            _addReviewButton(book),
          ],
        ),
        const SizedBox(height: 20),
        if (reviews.isEmpty)
          _reviewEmptyState()
        else
          ...reviews.map((r) => _reviewTile(book.id, r)),
      ],
    );
  }

  Widget _addReviewButton(Book book) {
    return Material(
      color: _primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReviewEditPage(bookId: book.id),
            ),
          );
        },
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: _primaryFg),
              const SizedBox(width: 6),
              Text(
                '追加',
                style: TextStyle(
                  color: _primaryFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewEmptyState() {
    return CustomPaint(
      painter: _DashedRRectPainter(color: _border, radius: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 64),
        decoration: BoxDecoration(
          color: _secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _muted,
              ),
              child: const Icon(Icons.star_border,
                  size: 20, color: _mutedFg),
            ),
            const SizedBox(height: 16),
            const Text(
              'まだレビューがありません',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _fg,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '最初のレビューを書いてみましょう',
              style: TextStyle(fontSize: 12, color: _mutedFg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewTile(String bookId, Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        title: Text(
          review.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _fg),
        ),
        subtitle: Text(
          review.updatedAt != null
              ? '更新: ${_formatDate(review.updatedAt!)}'
              : '作成: ${_formatDate(review.createdAt)}',
          style: const TextStyle(fontSize: 11, color: _mutedFg),
        ),
        trailing: const Icon(Icons.chevron_right, color: _mutedFg),
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
    final allCandidates = <String>{...widget.availableTags, ..._selected};
    final sortedCandidates = allCandidates.toList()..sort();
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

/// 日付セクションで扱う 1 エントリ（ラベル・値・更新ハンドラのセット）。
class _DateEntry {
  final String label;
  final DateTime? date;
  final Future<void> Function(DateTime) onChanged;
  const _DateEntry({
    required this.label,
    required this.date,
    required this.onChanged,
  });
}

/// 破線 rounded rect の CustomPainter。タグ枠・レビュー空状態に使う。
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, this.radius = 999});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashLength = 4.0;
    const gapLength = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dashLength, metric.length),
          ),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
