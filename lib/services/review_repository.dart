/// レビューを hive で CRUD する Repository（W5 で追加）。
///
/// BookRepository と並列の独立した Repository として実装（C1 採用）。
/// 責務分離: Book は本そのもの、Review は本に紐づく感想記録 を別々に保存。
library;

import 'package:hive_ce/hive.dart';
import 'package:sample/models/review.dart';

class ReviewRepository {
  /// hive box の名前（Book の 'books' とは別の box）。
  static const String boxName = 'reviews';

  late Box<Map> _box;

  ReviewRepository();

  /// テスト用 constructor。事前に開いた Box を注入する。
  ReviewRepository.test(Box<Map> box) : _box = box;

  /// hive を初期化（box を開く）。
  /// main() で `await Hive.initFlutter()` の後に必ず呼ぶ。
  Future<void> init() async {
    _box = await Hive.openBox<Map>(boxName);
  }

  /// 指定された Book.id に紐づくレビュー一覧を取得（作成日時の降順）。
  List<Review> getByBookId(String bookId) {
    final list = _box.values
        .map((m) => Review.fromMap(Map<String, dynamic>.from(m)))
        .where((r) => r.bookId == bookId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 1 件取得（id 指定）。存在しなければ null。
  Review? findById(String id) {
    final m = _box.get(id);
    if (m == null) return null;
    return Review.fromMap(Map<String, dynamic>.from(m));
  }

  /// レビューを追加 or 更新（upsert）。
  Future<void> save(Review review) async {
    await _box.put(review.id, review.toMap());
  }

  /// 指定 id のレビューを削除。
  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  /// 指定 Book.id に紐づくレビューを全削除。
  /// 将来「Book を本棚から削除した時に関連レビューも消す」用途に使う想定。
  Future<void> removeByBookId(String bookId) async {
    final ids = _box.values
        .map((m) => Review.fromMap(Map<String, dynamic>.from(m)))
        .where((r) => r.bookId == bookId)
        .map((r) => r.id)
        .toList();
    for (final id in ids) {
      await _box.delete(id);
    }
  }

  /// 全件削除（主にテスト用）。
  Future<void> clear() async {
    await _box.clear();
  }
}
