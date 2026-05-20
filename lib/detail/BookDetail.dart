import 'package:flutter/material.dart';
import '../models/book.dart';

/// 本の詳細モーダル（半透明オーバーレイ + 中央カード）。
///
/// W1 で Book モデルを受け取り、書名・著者・出版社・ステータス・進捗を表示する形に変更。
/// W4 で Stack モーダル → Navigator.push + Hero アニメに進化させる予定。
class BookDetail extends StatelessWidget {
  final Book book;
  final VoidCallback closeAction;

  const BookDetail({
    super.key,
    required this.book,
    required this.closeAction,
  });

  /// ステータスを日本語ラベルに変換。
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
            child: mainContent(),
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
        // 表紙画像（W3 で CachedNetworkImage 化予定）
        Center(child: Image.asset('assets/images/c_img.jpg')),
        const SizedBox(height: 12),
        // タイトル
        Text(
          book.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // 著者 / 出版社
        Text(
          '${book.author}${book.publisher != null ? "（${book.publisher}）" : ""}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        // ステータスと進捗
        bookInfoBox(),
        const SizedBox(height: 12),
        // 閉じるボタン
        Center(child: closeButton()),
      ],
    );
  }

  /// ステータス・ページ進捗・評価をまとめて表示するエリア。
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
          if (book.rating > 0) Text('評価: ${book.rating.toStringAsFixed(1)} / 5.0'),
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
