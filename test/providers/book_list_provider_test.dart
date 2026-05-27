// BookListNotifier / selectedBookProvider の Riverpod ロジックテスト。
//
// W1 ではダミー 7 件の static 前提のテストだったが、W3 で hive 経由に
// 変更したため、in-memory な FakeBookRepository を override で注入して
// テストする形に書き直した。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/services/book_repository.dart';

/// テスト用の in-memory な BookRepository 実装。
/// hive を使わずに動作するため、テストが軽量で安定する。
class _FakeBookRepository implements BookRepository {
  final Map<String, Book> _store = {};

  @override
  Future<void> init() async {}

  @override
  List<Book> getAll() => _store.values.toList();

  @override
  bool exists(String id) => _store.containsKey(id);

  @override
  Book? findById(String id) => _store[id];

  @override
  Future<void> save(Book book) async {
    _store[book.id] = book;
  }

  @override
  Future<void> remove(String id) async {
    _store.remove(id);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}

/// テスト用 ProviderContainer を生成するヘルパー。
ProviderContainer makeContainer() {
  final container = ProviderContainer(
    overrides: [
      bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
    ],
  );
  return container;
}

void main() {
  group('bookListProvider', () {
    test('初期状態は空（hive が空 = W3 でダミー廃止のため）', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(bookListProvider), isEmpty);
    });

    test('add で本が本棚に追加される', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      const book = Book(id: 'b1', title: 'Test', author: 'Author');
      await container.read(bookListProvider.notifier).add(book);

      final books = container.read(bookListProvider);
      expect(books, hasLength(1));
      expect(books.first.id, 'b1');
      expect(books.first.title, 'Test');
    });

    test('remove で本が削除される', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookListProvider.notifier);
      await notifier.add(const Book(id: 'b1', title: 'A', author: 'X'));
      expect(container.read(bookListProvider), hasLength(1));

      await notifier.remove('b1');
      expect(container.read(bookListProvider), isEmpty);
    });

    test('update で同じ id の本のフィールドが上書きされる', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookListProvider.notifier);
      await notifier.add(const Book(id: 'b1', title: 'Old', author: 'X'));
      await notifier.update(const Book(id: 'b1', title: 'New', author: 'X'));

      final books = container.read(bookListProvider);
      expect(books, hasLength(1));
      expect(books.first.title, 'New');
    });

    test('exists は登録済みなら true、未登録なら false', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookListProvider.notifier);
      await notifier.add(const Book(id: 'b1', title: 'T', author: 'A'));

      expect(notifier.exists('b1'), isTrue);
      expect(notifier.exists('b2'), isFalse);
    });
  });

  group('selectedBookProvider', () {
    test('初期値は null（モーダル閉じ状態）', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedBookProvider), isNull);
    });

    test('Book をセットでき、null に戻せる', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      const book = Book(id: 'b1', title: 'T', author: 'A');

      container.read(selectedBookProvider.notifier).state = book;
      expect(container.read(selectedBookProvider), equals(book));

      container.read(selectedBookProvider.notifier).state = null;
      expect(container.read(selectedBookProvider), isNull);
    });
  });
}
