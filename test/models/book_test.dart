// Book データモデルの単体テスト。
// W1 のコアロジックテスト（ハイブリッド方針の自動テスト側）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';

void main() {
  group('Book', () {
    test('デフォルト値が正しく設定される', () {
      const book = Book(id: '1', title: 'タイトル', author: '著者');

      expect(book.status, BookStatus.wantToRead);
      expect(book.currentPage, 0);
      expect(book.rating, 0.0);
      expect(book.isbn, isNull);
      expect(book.publisher, isNull);
      expect(book.totalPages, isNull);
      expect(book.startedAt, isNull);
      expect(book.finishedAt, isNull);
    });

    test('copyWith は指定したフィールドだけ更新する', () {
      const original = Book(
        id: '1',
        title: 'Original',
        author: 'Author A',
        status: BookStatus.wantToRead,
      );

      final updated = original.copyWith(
        title: 'Updated',
        status: BookStatus.reading,
      );

      expect(updated.id, '1');
      expect(updated.title, 'Updated');
      expect(updated.author, 'Author A'); // 変更していない
      expect(updated.status, BookStatus.reading);
    });

    test('== 演算子は id ベースで動く', () {
      const a = Book(id: '1', title: 'A', author: 'X');
      const b = Book(id: '1', title: 'B', author: 'Y');
      const c = Book(id: '2', title: 'A', author: 'X');

      expect(a, equals(b)); // id が同じなら等価
      expect(a, isNot(equals(c))); // id が違えば非等価
    });

    test('hashCode は id ベース', () {
      const a = Book(id: '1', title: 'A', author: 'X');
      const b = Book(id: '1', title: 'B', author: 'Y');

      expect(a.hashCode, equals(b.hashCode));
    });

    test('BookStatus の 3 値が enum として存在する', () {
      expect(BookStatus.values, hasLength(3));
      expect(BookStatus.values, contains(BookStatus.wantToRead));
      expect(BookStatus.values, contains(BookStatus.reading));
      expect(BookStatus.values, contains(BookStatus.finished));
    });
  });
}
