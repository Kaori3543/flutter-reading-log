/// 特定のタグが付いた本の一覧画面（W12 で新規追加）。
///
/// ライブラリタブのタグをタップすると遷移する画面。
/// 本棚タブと同じ BookListItem を縦に並べる。タップで本詳細へ。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../detail/BookDetail.dart';
import '../list/BookListItem.dart';
import '../providers/book_list_provider.dart';

class TagBooksPage extends ConsumerWidget {
  final String tag;

  const TagBooksPage({super.key, required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final tagged = books.where((b) => b.tags.contains(tag)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('#$tag'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: tagged.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'このタグの本はもうありません',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : ListView.builder(
              itemCount: tagged.length,
              itemBuilder: (context, index) {
                final book = tagged[index];
                return BookListItem(
                  book: book,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BookDetail(book: book)),
                    );
                  },
                );
              },
            ),
    );
  }
}
