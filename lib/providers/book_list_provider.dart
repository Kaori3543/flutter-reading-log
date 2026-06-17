/// 本棚の本のリストを保持する Riverpod provider。
///
/// W1 ではダミー Book 7 件を static で保持していたが、W3 で hive
/// 経由の永続データに置き換えた。
/// 検索結果からの追加・編集・削除は本 provider 経由で行う。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../services/book_repository.dart';
import '../services/review_repository.dart';
import 'book_view_settings_provider.dart';
import 'review_list_provider.dart';

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
  BookListNotifier(this._repository, this._reviewRepository) : super([]) {
    _load();
  }

  final BookRepository _repository;

  /// 本削除時に紐づくレビューも消すために保持（W6 で追加）。
  /// null 許容なのは、レビュー機能を必要としないテスト等で省略できるように。
  final ReviewRepository? _reviewRepository;

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

  /// 本を削除（W6 で拡張）。
  ///
  /// 紐づくレビューがあれば一緒に削除する。`ReviewRepository` を保持して
  /// いない場合（テスト等）は本データのみ削除する。
  Future<void> remove(String id) async {
    await _repository.remove(id);
    await _reviewRepository?.removeByBookId(id);
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
    // W7/W9 で genre / genreId / addedAt / isFavoriteAuthor が追加された後も
    // 既存値を保持するよう全フィールドを引き継ぐ（不在だと「ステータス変更で
    // ジャンルが消える」「お気に入り著者解除」などの不具合になる）。
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
      genre: book.genre,
      genreId: book.genreId,
      addedAt: book.addedAt,
      isFavoriteAuthor: book.isFavoriteAuthor,
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

  /// 読み始め日を更新（W9 で追加）。
  /// 「読書中」「読了」状態の本でユーザーが日付ピッカーで変更したときに呼ぶ。
  /// 進捗のリマインダー（R6）が条件を満たすかの確認にも使える。
  Future<void> updateStartedAt(String bookId, DateTime startedAt) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(book.copyWith(startedAt: startedAt));
    _load();
  }

  /// 読了日を更新（W9 で追加）。
  /// 「読了」状態の本でユーザーが日付ピッカーで変更したときに呼ぶ。
  Future<void> updateFinishedAt(String bookId, DateTime finishedAt) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(book.copyWith(finishedAt: finishedAt));
    _load();
  }

  /// 本棚に追加した日（addedAt）を更新（W9 で追加）。
  /// 「読みたい」状態の本で「いつ買ったか」を後から記録できるように。
  /// 積読放置リマインダー（R5）が条件を満たすかの確認にも使える。
  Future<void> updateAddedAt(String bookId, DateTime addedAt) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(book.copyWith(addedAt: addedAt));
    _load();
  }

  /// 「お気に入り著者にする」フラグを反転（W9 で追加）。
  /// ON の本の主著者だけが統計・おすすめでお気に入り著者として扱われる。
  Future<void> toggleFavoriteAuthor(String bookId) async {
    final book = _repository.findById(bookId);
    if (book == null) return;
    await _repository.save(
      book.copyWith(isFavoriteAuthor: !book.isFavoriteAuthor),
    );
    _load();
  }
}

/// 本棚の本のリストを公開する provider。
/// ConsumerWidget から `ref.watch(bookListProvider)` で参照する。
final bookListProvider =
    StateNotifierProvider<BookListNotifier, List<Book>>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  final reviewRepository = ref.watch(reviewRepositoryProvider);
  return BookListNotifier(repository, reviewRepository);
});

/// 本棚の表示設定（タブ/評価フィルタ/ソート）を適用した本リストを返す純粋関数。
///
/// W6 で追加。UI 側は `bookListProvider` と `bookViewSettingsProvider` を
/// 両方 watch し、本関数で組み合わせる。純粋関数なのでテストしやすい。
///
/// 適用順:
///   1. ステータスフィルタ（タブ）
///   2. 評価フィルタ（minRating 以上）
///   3. ソート
List<Book> applyBookView(List<Book> books, BookViewSettings settings) {
  Iterable<Book> result = books;

  if (settings.statusFilter != null) {
    result = result.where((b) => b.status == settings.statusFilter);
  }
  if (settings.minRating > 0.0) {
    result = result.where((b) => b.rating >= settings.minRating);
  }

  final list = result.toList();
  switch (settings.sort) {
    case BookSort.addedDesc:
      // id を時刻ベースで生成しているため、id 降順 ≒ 追加日降順
      list.sort((a, b) => b.id.compareTo(a.id));
      break;
    case BookSort.ratingDesc:
      list.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        if (byRating != 0) return byRating;
        // 同点の場合はタイトル昇順で安定化
        return a.title.compareTo(b.title);
      });
      break;
    case BookSort.titleAsc:
      list.sort((a, b) => a.title.compareTo(b.title));
      break;
    case BookSort.finishedDesc:
      list.sort((a, b) {
        // 読了日未設定は末尾に。
        final fa = a.finishedAt;
        final fb = b.finishedAt;
        if (fa == null && fb == null) return a.title.compareTo(b.title);
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      break;
  }
  return list;
}

