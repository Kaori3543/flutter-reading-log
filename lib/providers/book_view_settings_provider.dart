/// 本棚の表示設定（ステータスタブ・評価フィルタ・並び順）を保持する provider。
///
/// W6 で新規追加。本棚 UI は `bookListProvider` と本 provider の両方を
/// watch し、純粋関数 `applyBookView`（book_list_provider.dart）で
/// フィルタ＋ソートを適用してから描画する。
///
/// 設計メモ:
///   - 本データ（bookListProvider）と表示設定を分離する。hive に書き戻すのは
///     本データのみで、表示設定はセッション内のみ保持する（アプリ再起動で
///     「全て / 制限なし / 追加日順」に戻る）。
///   - ステータスタブと評価フィルタは AND 条件で適用。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';

/// 本棚の並び順種別。
enum BookSort {
  /// 追加日順（id の降順 = 新しいものが先）。デフォルト。
  addedDesc,

  /// 評価が高い順。
  ratingDesc,

  /// タイトル昇順（日本語/英語/かなが混ざる前提の単純比較）。
  titleAsc,

  /// 読了日が新しい順。読了していない本は末尾に。
  finishedDesc,
}

/// 並び順の表示名。
extension BookSortLabel on BookSort {
  String get label {
    switch (this) {
      case BookSort.addedDesc:
        return '追加日順';
      case BookSort.ratingDesc:
        return '評価が高い順';
      case BookSort.titleAsc:
        return 'タイトル順';
      case BookSort.finishedDesc:
        return '読了日が新しい順';
    }
  }
}

/// 本棚の表示設定スナップショット。
class BookViewSettings {
  /// 表示するステータス。null = 全て。
  final BookStatus? statusFilter;

  /// 最低評価フィルタ。0.0 = 制限なし、3.0 / 4.0 / 5.0 等。
  final double minRating;

  /// 並び順。
  final BookSort sort;

  /// 全文検索クエリ（W11 で追加）。空文字なら検索なし。
  /// タイトル / 著者 / 出版社 / ジャンル / レビュー本文を横断検索する。
  final String searchQuery;

  /// お気に入り本だけに絞り込むフラグ（W11 で追加）。
  /// 評価 Chip 帯の「♡だけ」と同期。
  final bool onlyFavorites;

  /// タグでの絞り込み（W12 で追加）。空 Set なら絞り込みなし。
  /// 複数選択時は OR 条件（どれか 1 つでも持っていれば一致）。
  /// 本棚タブの「タグで絞り込み」UI から設定する想定。
  final Set<String> tagFilters;

  const BookViewSettings({
    this.statusFilter,
    this.minRating = 0.0,
    this.sort = BookSort.addedDesc,
    this.searchQuery = '',
    this.onlyFavorites = false,
    this.tagFilters = const {},
  });

  BookViewSettings copyWith({
    Object? statusFilter = _unset,
    double? minRating,
    BookSort? sort,
    String? searchQuery,
    bool? onlyFavorites,
    Set<String>? tagFilters,
  }) {
    return BookViewSettings(
      statusFilter: identical(statusFilter, _unset)
          ? this.statusFilter
          : statusFilter as BookStatus?,
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
      searchQuery: searchQuery ?? this.searchQuery,
      onlyFavorites: onlyFavorites ?? this.onlyFavorites,
      tagFilters: tagFilters ?? this.tagFilters,
    );
  }

  static const _unset = Object();
}

class BookViewSettingsNotifier extends StateNotifier<BookViewSettings> {
  BookViewSettingsNotifier() : super(const BookViewSettings());

  /// ステータスタブを切替。null を渡すと「全て」。
  void setStatusFilter(BookStatus? status) {
    state = state.copyWith(statusFilter: status);
  }

  void setMinRating(double minRating) {
    state = state.copyWith(minRating: minRating);
  }

  void setSort(BookSort sort) {
    state = state.copyWith(sort: sort);
  }

  /// 検索クエリを更新（W11 で追加）。
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// 「♡だけ」フィルタを切替（W11 で追加）。
  void setOnlyFavorites(bool onlyFavorites) {
    state = state.copyWith(onlyFavorites: onlyFavorites);
  }

  /// タグ絞り込みを設定（W12 で追加）。空 Set でクリア。
  void setTagFilters(Set<String> tagFilters) {
    state = state.copyWith(tagFilters: tagFilters);
  }
}

final bookViewSettingsProvider =
    StateNotifierProvider<BookViewSettingsNotifier, BookViewSettings>(
  (ref) => BookViewSettingsNotifier(),
);
