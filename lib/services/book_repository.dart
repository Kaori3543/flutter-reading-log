/// 本棚の本データを hive に永続化する Repository。
///
/// W3 で導入。W1 のダミー Book 7 件は廃止し、ユーザーが検索 → 追加で
/// 登録した本だけが hive に保存される設計。
///
/// hive_ce (Community Edition) を採用した理由は plan / コミット 1 を参照。
/// Book は Book.toMap() / Book.fromMap() で Map に変換して保存する
/// （codegen 不要、シンプル）。
library;

import 'package:hive_ce/hive.dart';
import 'package:sample/models/book.dart';

class BookRepository {
  /// hive box の名前。1 アプリ内では一意。
  static const String boxName = 'books';

  /// hive box（Book を Map として保存）。init() で開く。
  late Box<Map> _box;

  /// 本番用 constructor。`init()` を呼んで box を開く必要がある。
  BookRepository();

  /// テスト用 constructor。事前に開いた Box を注入する。
  /// flutter_test では `await Hive.openBox<Map>('test_box')` のように
  /// テンポラリ box を作って渡す。
  BookRepository.test(Box<Map> box) : _box = box;

  /// hive を初期化（box を開く）。
  /// main() で `await Hive.initFlutter()` の後に必ず呼ぶ。
  Future<void> init() async {
    _box = await Hive.openBox<Map>(boxName);
  }

  /// 本棚に登録されている全ての本を取得。
  /// 順序は hive の挿入順。並び替えは provider 側で行う想定。
  List<Book> getAll() {
    return _box.values
        .map((m) => Book.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// 指定した id の本があるか。
  /// 検索結果から「本棚に追加」する前の重複チェックなどに使う。
  bool exists(String id) => _box.containsKey(id);

  /// 1 件取得（id 指定）。存在しなければ null。
  Book? findById(String id) {
    final m = _box.get(id);
    if (m == null) return null;
    return Book.fromMap(Map<String, dynamic>.from(m));
  }

  /// 本を追加 or 既存を更新（upsert）。
  Future<void> save(Book book) async {
    await _box.put(book.id, book.toMap());
  }

  /// 本を削除。
  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  /// 全削除（主にテスト用）。
  Future<void> clear() async {
    await _box.clear();
  }
}
