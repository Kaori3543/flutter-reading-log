// アプリ全体が例外なく起動できることを確認する smoke test。
//
// W3 で hive を導入したことで、bookRepositoryProvider が
// override されていないと初期化エラーになる。
// テストでは in-memory な FakeBookRepository を override で注入する。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sample/main.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/services/book_repository.dart';

/// テスト用の in-memory な BookRepository 実装。
/// hive box を使わずに動作するので、Hive.initFlutter() なしでテストできる。
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

void main() {
  testWidgets('App launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWithValue(_FakeBookRepository()),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
