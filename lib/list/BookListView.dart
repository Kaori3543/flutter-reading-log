/// 本棚画面のグリッドビュー。
///
/// UI 改修: 縦リスト (AnimatedList + 横長カード) を撤去し、
/// Figma デザインに合わせたグリッド (縦カード = ダーク茶グラデ帯 + 本文) にする。
/// 差分アニメは省略し、GridView.builder で毎回全体を再描画する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/detail/BookDetail.dart';
import 'package:sample/list/BookListItem.dart';
import '../providers/book_list_provider.dart';
import '../providers/book_view_settings_provider.dart';
import '../providers/review_list_provider.dart';

class BookListView extends ConsumerStatefulWidget {
  const BookListView({super.key});

  @override
  ConsumerState<BookListView> createState() => _BookListViewState();
}

class _BookListViewState extends ConsumerState<BookListView> {
  /// 全本のレビュー本文を bookId → 連結文字列の Map にする（W11 で追加）。
  /// 検索クエリが空のときは null を返す（applyBookView 側で受け取らない扱い）。
  /// ReviewRepository を直接読むので、最新の hive 状態を毎回反映する。
  Map<String, String>? _buildReviewTextMap(BookViewSettings settings) {
    if (settings.searchQuery.trim().isEmpty) return null;
    final repo = ref.read(reviewRepositoryProvider);
    final reviews = repo.getAll();
    final map = <String, String>{};
    for (final r in reviews) {
      final existing = map[r.bookId];
      map[r.bookId] = existing == null ? r.content : '$existing\n${r.content}';
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final settings = ref.watch(bookViewSettingsProvider);
    final list = applyBookView(
      books,
      settings,
      reviewTextsByBookId: _buildReviewTextMap(settings),
    );

    if (list.isEmpty) return _emptyState();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.68,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final book = list[index];
        return BookListItem(
          book: book,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookDetail(book: book)),
            );
          },
        );
      },
    );
  }

  /// 本棚が空のときの案内。フィルタで 0 件のときも同じ画面を流用する。
  Widget _emptyState() {
    final settings = ref.watch(bookViewSettingsProvider);
    final hasAnyFilter =
        settings.statusFilter != null || settings.minRating > 0.0;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasAnyFilter ? '該当する本がありません' : 'まだ本が登録されていません',
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            hasAnyFilter
                ? 'タブや評価フィルタを変えて確認してみてください'
                : '右上の + ボタンから本を追加しましょう',
            style: const TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
