/// 本の詳細ページ。
///
/// W1〜W3: BookListView の上に半透明オーバーレイで重なる Stack モーダル
/// W4: 独立した Scaffold ベースのページ + AppBar の戻る + 削除ボタン
///   - Stack モーダルから Navigator.push のページに進化（看板機能）
///   - 「本棚から削除」ボタンを AppBar の actions に追加
///   - 表紙画像を Hero(tag: 'cover-${book.id}') でラップして、本棚画面
///     （BookListItem）の表紙から滑らかに拡大しながら飛んでくる
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';

class BookDetail extends ConsumerWidget {
  final Book book;

  const BookDetail({super.key, required this.book});

  String _statusLabel() {
    switch (book.status) {
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

  /// 「本棚から削除」フロー。
  /// 確認ダイアログ → hive から削除 → 本棚画面に戻る + SnackBar 通知。
  Future<void> _confirmAndRemove(BuildContext context, WidgetRef ref) async {
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

    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${book.title}」を本棚から削除しました')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本の詳細'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '本棚から削除',
            onPressed: () => _confirmAndRemove(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _coverImage()),
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
            const SizedBox(height: 16),
            _bookInfoBox(),
          ],
        ),
      ),
    );
  }

  /// 表紙画像。Hero でラップして本棚画面の表紙と滑らかにつなぐ（W4 コミット 3）。
  Widget _coverImage() {
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

    // Hero アニメ。tag は Book.id ベースで一意。
    // 本棚画面（BookListItem）の表紙画像と同じ tag を使うことで、
    // 画面遷移時に表紙が滑らかに飛んで拡大する。
    return Hero(
      tag: 'cover-${book.id}',
      child: image,
    );
  }

  /// 本の読書状態（ステータス・進捗・評価・日付）をまとめた表示エリア。
  Widget _bookInfoBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ステータス: ${_statusLabel()}'),
          if (book.totalPages != null)
            Text('進捗: ${book.currentPage} / ${book.totalPages} ページ'),
          if (book.rating > 0)
            Text('評価: ${book.rating.toStringAsFixed(1)} / 5.0'),
          if (book.startedAt != null)
            Text('読み始め: ${_formatDate(book.startedAt!)}'),
          if (book.finishedAt != null)
            Text('読了: ${_formatDate(book.finishedAt!)}'),
        ],
      ),
    );
  }
}
