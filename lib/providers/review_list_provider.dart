/// 指定された Book に紐づくレビュー一覧を保持する Riverpod provider。
///
/// W5 で追加。`StateNotifierProvider.family` を使い、Book.id をキーに
/// レビュー一覧を独立した state として持つ。これにより、同時に複数の
/// 本の詳細ページが開いても、それぞれのレビューが独立して管理される。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/review.dart';
import '../services/review_repository.dart';

/// ReviewRepository を Riverpod 経由で公開する provider。
/// main() で初期化済みの実 Repository を override で注入する前提。
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  throw UnimplementedError(
    'reviewRepositoryProvider must be overridden in main() with an initialized ReviewRepository',
  );
});

/// 指定 Book.id のレビュー一覧を管理する StateNotifier。
class ReviewListNotifier extends StateNotifier<List<Review>> {
  ReviewListNotifier(this._repository, this._bookId) : super([]) {
    _load();
  }

  final ReviewRepository _repository;
  final String _bookId;

  /// hive から該当 Book のレビュー一覧を読み込んで state にセット。
  void _load() {
    state = _repository.getByBookId(_bookId);
  }

  /// レビューを追加（新規作成）。
  Future<void> add(Review review) async {
    await _repository.save(review);
    _load();
  }

  /// レビューを更新。updatedAt を自動でセット。
  Future<void> update(Review review) async {
    await _repository.save(review.copyWith(updatedAt: DateTime.now()));
    _load();
  }

  /// レビューを削除。
  Future<void> remove(String id) async {
    await _repository.remove(id);
    _load();
  }
}

/// Book.id ごとのレビュー一覧 provider（family）。
/// 使い方: `ref.watch(reviewListProvider(book.id))`
final reviewListProvider = StateNotifierProvider.family<
    ReviewListNotifier, List<Review>, String>(
  (ref, bookId) {
    final repository = ref.watch(reviewRepositoryProvider);
    return ReviewListNotifier(repository, bookId);
  },
);
