/// 本棚画面のグリッドビュー。
///
/// UI 改修: 縦リスト (AnimatedList + 横長カード) を撤去し、
/// Figma デザインに合わせたグリッド (縦カード = ダーク茶グラデ帯 + 本文) にする。
/// 差分アニメは省略し、GridView.builder で毎回全体を再描画する。
library;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:sample/detail/BookDetail.dart';
import 'package:sample/list/BookListItem.dart';
import '../providers/book_list_provider.dart';
import '../providers/book_view_settings_provider.dart';
import '../providers/review_list_provider.dart';
import '../theme/app_theme.dart';

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

    // AnimationLimiter で「表示直後の 1 回だけ」stagger アニメが働く。
    // フィルタや検索で list が変わっても再度アニメーションする。
    return AnimationLimiter(
      key: ValueKey(list.length),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.58,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final book = list[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            columnCount: 3,
            duration: const Duration(milliseconds: 420),
            child: ScaleAnimation(
              scale: 0.92,
              child: FadeInAnimation(
                // OpenContainer: タップされたカードが「変形」しながら本詳細
                // に展開する Material Motion トランジション。閉じるときも
                // 同じ経路で戻る。BookListItem 自体の onPressed は
                // openContainer コールバックに繋げて、ボタン領域外のカード
                // タップからも遷移するようにする。
                child: OpenContainer(
                  transitionType: ContainerTransitionType.fadeThrough,
                  transitionDuration: const Duration(milliseconds: 480),
                  openColor: AppColors.bg,
                  closedColor: Colors.white,
                  closedElevation: 0,
                  closedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  openBuilder: (context, _) => BookDetail(book: book),
                  closedBuilder: (context, openContainer) => BookListItem(
                    book: book,
                    onPressed: openContainer,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
