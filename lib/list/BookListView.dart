import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/list/BookListItem.dart';
import '../providers/book_list_provider.dart';

/// 本棚画面（W3 で hive 経由のデータ駆動に変更）。
///
/// W1: ListView + BookListItem（ダミー 7 件）
/// W3: ListView + BookListItem（hive 由来の `List<Book>`、ダミー廃止、empty state 追加）
///
/// W3 で一度 GridView 化を試したが、本が少ない時に縦長カードが画面いっぱいに
/// 広がって見づらかったため、W2 と同じ ListView 形式（横長カード）に戻した。
/// 「本のタイトル・著者・出版社・進捗日付・詳細ボタン」を 1 行に並べる方が
/// 情報密度として読みやすい。
class BookListView extends ConsumerWidget {
  const BookListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);

    if (books.isEmpty) {
      return _emptyState();
    }

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return BookListItem(
            book: book,
            onPressed: () {
              // 詳細モーダルを開く: 選択中の本を Riverpod state にセット
              ref.read(selectedBookProvider.notifier).state = book;
            },
          );
        },
      ),
    );
  }

  /// 本棚が空のときに表示する案内（W3 でダミー廃止 → 初回起動が空になるため追加）。
  Widget _emptyState() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'まだ本が登録されていません',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            const Text(
              '右下の検索ボタンから本を追加しましょう',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
