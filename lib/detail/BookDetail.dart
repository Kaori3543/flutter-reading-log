import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';

/// 本の詳細モーダル（半透明オーバーレイ + 中央カード）。
///
/// W1 で Book モデル受け取り版に変更。
/// W3 で表紙画像を Image.asset → CachedNetworkImage に置換。
/// W4 で Stack モーダル → Navigator.push + Hero アニメに進化させる予定。
class BookDetail extends StatelessWidget {
  final Book book;
  final VoidCallback closeAction;

  const BookDetail({
    super.key,
    required this.book,
    required this.closeAction,
  });

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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(0, 0, 0, 0.5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              boxShadow: const [
                BoxShadow(color: Colors.grey, blurRadius: 5),
              ],
            ),
            child: SingleChildScrollView(child: mainContent()),
          ),
        ),
      ),
    );
  }

  Widget mainContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _coverImage()),
        const SizedBox(height: 12),
        Text(
          book.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${book.author}${book.publisher != null ? "（${book.publisher}）" : ""}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        bookInfoBox(),
        const SizedBox(height: 12),
        Center(child: closeButton()),
      ],
    );
  }

  /// 表紙画像。W3 で CachedNetworkImage 化。
  /// URL が無い場合はアイコンのプレースホルダー。
  Widget _coverImage() {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 120,
        height: 180,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book, size: 60, color: Colors.black54),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: 180,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        width: 120,
        height: 180,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }

  Widget bookInfoBox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ステータス: ${_statusLabel()}'),
          if (book.totalPages != null)
            Text('進捗: ${book.currentPage} / ${book.totalPages} ページ'),
          if (book.rating > 0)
            Text('評価: ${book.rating.toStringAsFixed(1)} / 5.0'),
        ],
      ),
    );
  }

  Widget closeButton() {
    return SizedBox(
      width: 200,
      child: ElevatedButton(
        onPressed: closeAction,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(Colors.red),
          foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: FittedBox(fit: BoxFit.contain, child: Text('閉じる')),
        ),
      ),
    );
  }
}
