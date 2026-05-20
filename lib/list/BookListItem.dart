import 'package:flutter/material.dart';
import 'package:sample/list/MainContent.dart';
import '../models/book.dart';

/// 本棚のリストアイテム（1 冊分のカード）。
/// W1 で Book モデルを受け取る形に変更。
/// 表紙画像は W3 で CachedNetworkImage + 楽天 API 由来の URL に置換予定。
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
            child: imageWidget(),
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
  /// W1 では全 Book で c_img.jpg を共通使用（楽天 API 未導入のため）。
  /// W3 で book.coverImageUrl を CachedNetworkImage で表示する形に置換予定。
  Widget imageWidget() {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: Image.asset(
          'assets/images/c_img.jpg',
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 100,
              height: 100,
              color: Colors.red[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 30),
                  const SizedBox(height: 4),
                  const Text(
                    '画像読み込みエラー',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'asset not found',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 8,
                      decoration: TextDecoration.lineThrough,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
