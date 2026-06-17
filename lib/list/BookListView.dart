/// 本棚画面。
///
/// W1: ListView + BookListItem（ダミー 7 件）
/// W3: hive 由来 + empty state
/// W4: タップ時の遷移を Navigator.push に変更
/// W6: ListView.builder → AnimatedList に変更。
///     bookListProvider と bookViewSettingsProvider の両方を listen し、
///     applyBookView 適用後のリストとの差分を取って insertItem / removeItem
///     をアニメーション付きで適用する。
///     並び替え（順序変更のみ）も「remove → insert」で擬似的にアニメ化する。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/detail/BookDetail.dart';
import 'package:sample/list/BookListItem.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../providers/book_view_settings_provider.dart';
import '../providers/review_list_provider.dart';

class BookListView extends ConsumerStatefulWidget {
  const BookListView({super.key});

  @override
  ConsumerState<BookListView> createState() => _BookListViewState();
}

class _BookListViewState extends ConsumerState<BookListView> {
  final GlobalKey<AnimatedListState> _listKey =
      GlobalKey<AnimatedListState>();

  /// AnimatedList に同期して保持するローカルなリスト。
  /// provider の state とは別物で、AnimatedList の internal state と
  /// 一致させ続ける責務がある。
  List<Book> _displayed = [];

  static const _animDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    // 初期表示用にフィルタ＋ソート適用済みのリストをコピー。
    final books = ref.read(bookListProvider);
    final settings = ref.read(bookViewSettingsProvider);
    _displayed = List<Book>.from(applyBookView(books, settings));
  }

  /// 期待される最終リスト（[target]）と現在の `_displayed` の差分を取り、
  /// AnimatedList の insertItem / removeItem を順番に呼ぶ。
  void _syncList(List<Book> target) {
    final listState = _listKey.currentState;
    // AnimatedList がまだ build されていない / empty state からの復帰時は
    // setState で全置換する（アニメーションは諦める）。
    if (listState == null) {
      setState(() => _displayed = List<Book>.from(target));
      return;
    }

    final targetIds = target.map((b) => b.id).toSet();

    // 1. 旧リストにあるが新リストに無いものを削除（後ろから）
    for (int i = _displayed.length - 1; i >= 0; i--) {
      if (!targetIds.contains(_displayed[i].id)) {
        final removed = _displayed.removeAt(i);
        listState.removeItem(
          i,
          (context, animation) => _buildItem(removed, animation),
          duration: _animDuration,
        );
      }
    }

    // 2. 新リストの順序に合わせて _displayed を整える。
    //    各 newIdx について
    //      - _displayed に無ければ insertItem で追加
    //      - 位置がズレていれば remove → insert で再配置
    for (int newIdx = 0; newIdx < target.length; newIdx++) {
      final book = target[newIdx];
      final curIdx = _displayed.indexWhere((b) => b.id == book.id);

      if (curIdx == -1) {
        _displayed.insert(newIdx, book);
        listState.insertItem(newIdx, duration: _animDuration);
      } else if (curIdx != newIdx) {
        final moving = _displayed.removeAt(curIdx);
        listState.removeItem(
          curIdx,
          (context, animation) => _buildItem(moving, animation),
          duration: _animDuration,
        );
        _displayed.insert(newIdx, book);
        listState.insertItem(newIdx, duration: _animDuration);
      } else {
        // 同位置の本でも内容（評価・ステータス等）が変わっている可能性が
        // あるので最新の book を反映する。アニメーションは不要。
        _displayed[newIdx] = book;
      }
    }
  }

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
    // bookListProvider または表示設定が変わったら _syncList で差分適用する。
    ref.listen<List<Book>>(bookListProvider, (prev, next) {
      final settings = ref.read(bookViewSettingsProvider);
      _syncList(applyBookView(
        next,
        settings,
        reviewTextsByBookId: _buildReviewTextMap(settings),
      ));
    });
    ref.listen<BookViewSettings>(bookViewSettingsProvider, (prev, next) {
      final books = ref.read(bookListProvider);
      _syncList(applyBookView(
        books,
        next,
        reviewTextsByBookId: _buildReviewTextMap(next),
      ));
    });

    // 本棚全体が空（フィルタ後 0 件含む）なら案内画面を出す。
    // _displayed が 0 件のときは AnimatedList を生成すると key 取得や
    // initialItemCount=0 から insertItem への遷移が複雑になるため、
    // 完全な切替で運用する。
    if (_displayed.isEmpty) {
      return _emptyState();
    }

    return Container(
      color: Colors.white,
      child: AnimatedList(
        key: _listKey,
        initialItemCount: _displayed.length,
        itemBuilder: (context, index, animation) {
          return _buildItem(_displayed[index], animation);
        },
      ),
    );
  }

  Widget _buildItem(Book book, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: BookListItem(
          book: book,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BookDetail(book: book)),
            );
          },
        ),
      ),
    );
  }

  /// 本棚が空のときの案内。フィルタで 0 件のときも同じ画面を流用する。
  Widget _emptyState() {
    final settings = ref.watch(bookViewSettingsProvider);
    final hasAnyFilter =
        settings.statusFilter != null || settings.minRating > 0.0;

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
            Text(
              hasAnyFilter ? '該当する本がありません' : 'まだ本が登録されていません',
              style:
                  const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              hasAnyFilter
                  ? 'タブや評価フィルタを変えて確認してみてください'
                  : '右下の検索ボタンから本を追加しましょう',
              style:
                  const TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
