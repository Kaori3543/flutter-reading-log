import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sample/list/MainContent.dart';
import '../models/book.dart';

/// 検索結果や横長リストで使う「1 冊分のカード」。
///
/// 本棚画面では W3 で導入した BookGridItem (GridView) を使うため、
/// このウィジェットは主に SearchPage の検索結果一覧で使われる。
class BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback onPressed;

  const BookListItem({
    super.key,
    required this.book,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.grey, blurRadius: 3)],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: Colors.white,
              boxShadow: const [BoxShadow(color: Colors.grey, blurRadius: 1)],
            ),
            child: _imageWidget(),
          ),
          Expanded(
            child: SizedBox(
              height: 100,
              child: MainContent(book: book, onPressed: onPressed),
            ),
          ),
        ],
      ),
    );
  }

  /// 表紙画像を表示。
  ///
  /// W3 で楽天 API 由来の URL を CachedNetworkImage で表示する形に置換した。
  /// URL が無い本（楽天で画像が取得できなかった場合）はプレースホルダー
  /// のアイコンを表示する。
  Widget _imageWidget() {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book, size: 40, color: Colors.black54),
        ),
      );
    }
    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade100,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
