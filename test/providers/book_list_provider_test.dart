// BookListNotifier / selectedBookProvider の Riverpod ロジックテスト。
// ProviderContainer を使い、Widget を介さずに provider の動作を検証する。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';

void main() {
  group('bookListProvider', () {
    test('初期状態でダミー本 7 冊が含まれる', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final books = container.read(bookListProvider);

      expect(books, hasLength(7));
    });

    test('全ての本の id がユニーク', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final books = container.read(bookListProvider);
      final ids = books.map((b) => b.id).toSet();

      expect(ids, hasLength(7));
    });

    test('ステータス分布: finished 3 / reading 2 / wantToRead 2', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final books = container.read(bookListProvider);
      final finished =
          books.where((b) => b.status == BookStatus.finished).length;
      final reading =
          books.where((b) => b.status == BookStatus.reading).length;
      final wantToRead =
          books.where((b) => b.status == BookStatus.wantToRead).length;

      expect(finished, 3);
      expect(reading, 2);
      expect(wantToRead, 2);
    });

    test('finished な本は全て finishedAt が設定されている', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final finished = container
          .read(bookListProvider)
          .where((b) => b.status == BookStatus.finished);

      for (final book in finished) {
        expect(book.finishedAt, isNotNull,
            reason: '読了の本には finishedAt が必要: ${book.title}');
      }
    });

    test('reading な本は currentPage > 0 かつ totalPages 未満', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reading = container
          .read(bookListProvider)
          .where((b) => b.status == BookStatus.reading);

      for (final book in reading) {
        expect(book.currentPage, greaterThan(0),
            reason: '読書中の本には currentPage > 0 が必要: ${book.title}');
        if (book.totalPages != null) {
          expect(book.currentPage, lessThan(book.totalPages!),
              reason: '読書中なら currentPage < totalPages: ${book.title}');
        }
      }
    });
  });

  group('selectedBookProvider', () {
    test('初期値は null（モーダル閉じ状態）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedBookProvider), isNull);
    });

    test('Book をセットでき、null に戻せる', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const book = Book(id: 'test-1', title: 'テスト本', author: 'テスト著者');

      // セット
      container.read(selectedBookProvider.notifier).state = book;
      expect(container.read(selectedBookProvider), equals(book));

      // null に戻す
      container.read(selectedBookProvider.notifier).state = null;
      expect(container.read(selectedBookProvider), isNull);
    });
  });
}
