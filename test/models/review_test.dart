// Review データモデルの単体テスト。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/review.dart';

void main() {
  group('Review', () {
    test('copyWith は指定したフィールドだけ更新する', () {
      final original = Review(
        id: 'r1',
        bookId: 'book-1',
        content: '元の内容',
        createdAt: DateTime(2026, 5, 20),
      );

      final updated = original.copyWith(content: '更新後の内容');

      expect(updated.id, 'r1');
      expect(updated.bookId, 'book-1');
      expect(updated.content, '更新後の内容');
      expect(updated.createdAt, DateTime(2026, 5, 20));
    });

    test('== 演算子は id ベースで動く', () {
      final a = Review(
        id: 'r1',
        bookId: 'book-1',
        content: 'A',
        createdAt: DateTime(2026, 5, 20),
      );
      final b = Review(
        id: 'r1',
        bookId: 'book-2',
        content: 'B',
        createdAt: DateTime(2026, 5, 21),
      );
      final c = Review(
        id: 'r2',
        bookId: 'book-1',
        content: 'A',
        createdAt: DateTime(2026, 5, 20),
      );

      expect(a, equals(b)); // id が同じなら等価
      expect(a, isNot(equals(c))); // id が違えば非等価
    });
  });
}
