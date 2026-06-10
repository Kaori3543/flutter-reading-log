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

  const BookViewSettings({
    this.statusFilter,
    this.minRating = 0.0,
    this.sort = BookSort.addedDesc,
  });

  BookViewSettings copyWith({
    Object? statusFilter = _unset,
    double? minRating,
    BookSort? sort,
  }) {
    return BookViewSettings(
      statusFilter: identical(statusFilter, _unset)
          ? this.statusFilter
          : statusFilter as BookStatus?,
      minRating: minRating ?? this.minRating,
      sort: sort ?? this.sort,
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
}

final bookViewSettingsProvider =
    StateNotifierProvider<BookViewSettingsNotifier, BookViewSettings>(
  (ref) => BookViewSettingsNotifier(),
);
