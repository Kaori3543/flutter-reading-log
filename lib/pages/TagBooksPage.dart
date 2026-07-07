/// 特定のタグが付いた本の一覧画面（W12 で新規追加）。
///
/// ライブラリタブのタグをタップすると遷移する画面。
/// 本棚と同じ縦グリッドカードを敷き詰めて表示する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
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
          : AnimationLimiter(
              key: ValueKey('tag-$tag-${tagged.length}'),
              child: GridView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.68,
                ),
                itemCount: tagged.length,
                itemBuilder: (context, index) {
                  final book = tagged[index];
                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    columnCount: 3,
                    duration: const Duration(milliseconds: 420),
                    child: ScaleAnimation(
                      scale: 0.92,
                      child: FadeInAnimation(
                        child: BookListItem(
                          book: book,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => BookDetail(book: book)),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
