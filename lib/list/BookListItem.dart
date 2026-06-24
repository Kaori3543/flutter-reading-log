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
    // UI/UX: 上品な雰囲気にするため、強めの灰色シャドウを薄く控えめなものに変更。
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // black 8%
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 表紙コンテナの右上に♥マークを重ねるため Stack でラップ（W11）。
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 表紙画像コンテナ。輪郭は細い線で控えめに。
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0x14000000),
                    width: 0.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageWidget(),
              ),
              if (book.isFavorite)
                Positioned(
                  top: -4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      size: 14,
                      color: Colors.pink,
                    ),
                  ),
                ),
            ],
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
          child: Icon(Icons.book_outlined, size: 40, color: Colors.black54),
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
