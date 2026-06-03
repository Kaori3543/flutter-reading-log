import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sample/list/MainContent.dart';
import '../models/book.dart';

/// 検索結果や横長リストで使う「1 冊分のカード」。
///
/// W3: Image.asset → CachedNetworkImage に置換
/// W4: 表紙画像を Hero(tag: 'cover-${book.id}') でラップ。
///     本棚画面 → BookDetail ページ遷移時に、表紙が滑らかに飛んで拡大する。
///     SearchPage では Navigator.push しないので Hero は発火しないが、
///     ウィジェット自体は同じものを使えるよう、共通でラップしている。
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

  /// 表紙画像。
  /// W3 で CachedNetworkImage 化、W4 で Hero ラップを追加。
  Widget _imageWidget() {
    final url = book.coverImageUrl;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book, size: 40, color: Colors.black54),
        ),
      );
    } else {
      image = ClipRect(
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

    // W4: Hero アニメ。tag は Book.id ベースで一意。
    // 本棚画面の表紙 → BookDetail の表紙 と同じ tag を使うことで遷移時に
    // 滑らかに拡大しながら飛ぶアニメが発火する。
    return Hero(
      tag: 'cover-${book.id}',
      child: image,
    );
  }
}
