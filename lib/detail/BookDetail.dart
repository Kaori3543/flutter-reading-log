/// 本の詳細ページ。
///
/// W4: Stack モーダル → Navigator.push の独立ページに進化、Hero アニメ追加
/// W5: 編集 UI を追加
///   - ChoiceChip でステータス変更（読みたい / 読書中 / 読了）
///   - flutter_rating_bar で ★評価（5 段階）
///   - TextField で進捗（currentPage）の編集
///   - レビュー一覧 UI は次のコミット（W5 コミット 5）で追加する
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';

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

    await ref.read(bookListProvider.notifier).remove(book.id);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${book.title}」を本棚から削除しました')),
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
    // 削除されたら null になり、自動で本棚画面に戻す。
    final books = ref.watch(bookListProvider);
    final book = books.where((b) => b.id == widget.book.id).firstOrNull;

    if (book == null) {
      // 本が hive から削除された場合、自動でこのページを閉じる
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('本の詳細'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
            const SizedBox(height: 20),
            _statusEditor(book),
            const SizedBox(height: 16),
            _ratingEditor(book),
            const SizedBox(height: 16),
            if (book.totalPages != null) _progressEditor(book),
            const SizedBox(height: 16),
            _dateInfo(book),
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
          child: Icon(Icons.book, size: 80, color: Colors.black54),
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

  /// ステータス変更 UI（W5）：ChoiceChip の横並び。
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

  /// ★評価 UI（W5）：flutter_rating_bar。
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
          ],
        ),
      ],
    );
  }

  /// 進捗編集 UI（W5）：TextField で現在のページ数 + 「更新」ボタン。
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

  /// 読書日付の表示エリア（読み始め / 読了）。編集はステータス変更時に自動。
  Widget _dateInfo(Book book) {
    if (book.startedAt == null && book.finishedAt == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (book.startedAt != null)
            Text('読み始め: ${_formatDate(book.startedAt!)}'),
          if (book.finishedAt != null)
            Text('読了: ${_formatDate(book.finishedAt!)}'),
        ],
      ),
    );
  }
}
