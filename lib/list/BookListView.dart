import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/list/BookListItem.dart';
import '../providers/book_list_provider.dart';

/// 本棚（本の一覧）画面。
///
/// W1 で大きく変更：
/// - StatelessWidget → ConsumerWidget（Riverpod 経由でデータ取得するため）
/// - 固定数 `items = [0..6]` → `bookListProvider` から得た `List<Book>`
/// - カードのタップでは `selectedBookProvider` に Book を入れて詳細モーダルを開く
///
/// なぜ ConsumerWidget か:
/// - StateNotifierProvider と一緒に使う標準的なパターン
/// - ref.watch でリアクティブに再描画される（本の追加・削除・編集が
///   将来発生したときに、自動で UI が更新される）
class BookListView extends ConsumerWidget {
  const BookListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);

    return Container(
      color: Colors.white,
      child: ListView.builder(
        itemCount: books.length,
        itemBuilder: (BuildContext context, int index) {
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
}
