import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/detail/BookDetail.dart';
import 'package:sample/list/BookListItem.dart';
import '../providers/book_list_provider.dart';

/// 本棚画面（ListView 形式、hive 由来の `List<Book>` を表示）。
///
/// W1: ListView + BookListItem（ダミー 7 件）
/// W3: hive 由来 + empty state
/// W4: タップ時の遷移を Stack モーダル → Navigator.push に変更。
///     selectedBookProvider への state セットも廃止し、直接 Navigator で
///     BookDetail ページを開く。
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
              // W4: 詳細ページに Navigator.push で遷移（Hero アニメ付き）
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BookDetail(book: book)),
              );
            },
          );
        },
      ),
    );
  }

  /// 本棚が空のときに表示する案内（W3 でダミー廃止 → 初回起動が空になるため）。
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
