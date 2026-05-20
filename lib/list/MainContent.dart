import 'package:flutter/material.dart';
import '../models/book.dart';

/// 本棚のカードの「右側」コンテンツ。
/// 旧クーポン UI 雛形では「タイトル」「2021/07/21」が固定文字列だったが、
/// W1 で Book モデルから値を受け取って表示する形に変更。
class MainContent extends StatelessWidget {
  final Book book;
  final VoidCallback onPressed;

  const MainContent({
    super.key,
    required this.book,
    required this.onPressed,
  });

  /// カードに表示する日付。
  /// 読了日 → 読み始め日 → 「未読」の優先順位で決定する。
  String _displayDate() {
    final dt = book.finishedAt ?? book.startedAt;
    if (dt == null) return '未読';
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  book.title,
                  style: const TextStyle(
                    color: Colors.black,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${book.author}\n${book.publisher ?? ""}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 20,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: onPressed,
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Colors.red),
                    foregroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.0),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Text('詳細を見る'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: FittedBox(
                    fit: BoxFit.fitHeight,
                    child: Text(
                      _displayDate(),
                      style: const TextStyle(
                        color: Colors.black,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
