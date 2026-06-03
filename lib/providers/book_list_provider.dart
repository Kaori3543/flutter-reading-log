/// 本棚の本のリストを保持する Riverpod provider。
///
/// W1 ではダミー Book 7 件を static で保持していたが、W3 で hive
/// 経由の永続データに置き換えた。
/// 検索結果からの追加・編集・削除は本 provider 経由で行う。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/book_repository.dart';

/// BookRepository を共有する Provider。
///
/// main() で実際の Repository（init 済み）を `overrideWithValue` で
/// 注入する。テストでは fake repository を注入できる。
final bookRepositoryProvider = Provider<BookRepository>((ref) {
  throw UnimplementedError(
    'bookRepositoryProvider must be overridden in main() '
    'with an initialized BookRepository',
  );
});

/// 本棚の本リストを管理する StateNotifier。
///
/// W3 で大きく変更：
/// - ダミー 7 件の static リスト → BookRepository 経由の hive データ
/// - add / update / remove の各操作で hive に書き込み + state 同期
class BookListNotifier extends StateNotifier<List<Book>> {
  BookListNotifier(this._repository) : super([]) {
    _load();
  }

  final BookRepository _repository;

  /// hive から本リストを読み込んで state にセット。
  /// 初期化時 + 変更操作の後に呼ぶ。
  void _load() {
    state = _repository.getAll();
  }

  /// 本を追加（または既存なら上書き）し、本棚を再ロード。
  Future<void> add(Book book) async {
    await _repository.save(book);
    _load();
  }

  /// 本のフィールドを更新。
  Future<void> update(Book book) async {
    await _repository.save(book);
    _load();
  }

  /// 本を削除。
  Future<void> remove(String id) async {
    await _repository.remove(id);
    _load();
  }

  /// 同じ id の本が既に登録されているか。
  /// 検索結果からの「追加」前に重複をユーザーに知らせる目的。
  bool exists(String id) => _repository.exists(id);

  /// 本のステータスを変更（W5 で追加、自動で日付もセット）。
  ///
  /// - 「読みたい → 読書中」: startedAt = 今日
  /// - 「読書中 or 読みたい → 読了」: finishedAt = 今日、currentPage = totalPages
  /// - 「読了 → 読書中」: finishedAt = null（再読扱い）
  Future<void> updateStatus(String bookId, BookStatus newStatus) async {
    final book = _repository.findById(bookId);
    if (book == null) return;

    final now = DateTime.now();
    DateTime? startedAt = book.startedAt;
    DateTime? finishedAt = book.finishedAt;
    int currentPage = book.currentPage;

    // 「読みたい → 読書中」
    if (newStatus == BookStatus.reading &&
        book.status == BookStatus.wantToRead) {
      startedAt = now;
    }
    // 「読書中 or 読みたい → 読了」
    if (newStatus == BookStatus.finished &&
        book.status != BookStatus.finished) {
      finishedAt = now;
      if (book.totalPages != null) {
        currentPage = book.totalPages!;
      }
    }
    // 「読了 → 読書中」（再読扱い、finishedAt をクリア）
    if (newStatus == BookStatus.reading &&
        book.status == BookStatus.finished) {
      finishedAt = null;
    }

    // copyWith では null を意図的にセットできないため、直接 Book を生成。
    final updated = Book(
      id: book.id,
      isbn: book.isbn,
      title: book.title,
      author: book.author,
      publisher: book.publisher,
      coverImageUrl: book.coverImageUrl,
      totalPages: book.totalPages,
      status: newStatus,
      currentPage: currentPage,
      rating: book.rating,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
    await _repository.save(updated);
    _load();
  }

  /// 本の評価を変更（W5 で追加、0.0 〜 5.0）。
  Future<void> updateRating(String bookId, double rating) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(book.copyWith(rating: rating));
    _load();
  }

  /// 本の進捗（currentPage）を更新（W5 で追加）。
  Future<void> updateProgress(String bookId, int currentPage) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(book.copyWith(currentPage: currentPage));
    _load();
  }
}

/// 本棚の本のリストを公開する provider。
/// ConsumerWidget から `ref.watch(bookListProvider)` で参照する。
final bookListProvider =
    StateNotifierProvider<BookListNotifier, List<Book>>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return BookListNotifier(repository);
});

