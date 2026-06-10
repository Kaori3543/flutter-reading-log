// 本棚の表示設定（フィルタ + ソート）を適用する純粋関数 `applyBookView` の
// 単体テスト。W6 で追加。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/providers/book_view_settings_provider.dart';

Book makeBook(
  String id, {
  String? title,
  BookStatus status = BookStatus.wantToRead,
  double rating = 0.0,
  DateTime? finishedAt,
}) {
  return Book(
    id: id,
    title: title ?? 'title-$id',
    author: 'author-$id',
    status: status,
    rating: rating,
    finishedAt: finishedAt,
  );
}

void main() {
  group('applyBookView - フィルタ', () {
    test('statusFilter = null は全件返す', () {
      final books = [
        makeBook('1', status: BookStatus.wantToRead),
        makeBook('2', status: BookStatus.reading),
        makeBook('3', status: BookStatus.finished),
      ];
      final result =
          applyBookView(books, const BookViewSettings(statusFilter: null));
      expect(result, hasLength(3));
    });

    test('statusFilter = 読書中 は読書中の本だけ返す', () {
      final books = [
        makeBook('1', status: BookStatus.wantToRead),
        makeBook('2', status: BookStatus.reading),
        makeBook('3', status: BookStatus.reading),
        makeBook('4', status: BookStatus.finished),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(statusFilter: BookStatus.reading),
      );
      expect(result.map((b) => b.id), unorderedEquals(['2', '3']));
    });

    test('minRating = 3.0 は ★3.0 以上の本だけ返す', () {
      final books = [
        makeBook('1', rating: 0.0),
        makeBook('2', rating: 2.5),
        makeBook('3', rating: 3.0),
        makeBook('4', rating: 4.5),
        makeBook('5', rating: 5.0),
      ];
      final result =
          applyBookView(books, const BookViewSettings(minRating: 3.0));
      expect(result.map((b) => b.id), unorderedEquals(['3', '4', '5']));
    });

    test('minRating = 0.0 は評価フィルタなし（0 評価も返す）', () {
      final books = [
        makeBook('1', rating: 0.0),
        makeBook('2', rating: 3.5),
      ];
      final result =
          applyBookView(books, const BookViewSettings(minRating: 0.0));
      expect(result, hasLength(2));
    });

    test('statusFilter と minRating は AND 条件で適用される', () {
      final books = [
        makeBook('1', status: BookStatus.reading, rating: 4.0),
        makeBook('2', status: BookStatus.reading, rating: 2.0),
        makeBook('3', status: BookStatus.finished, rating: 5.0),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(
          statusFilter: BookStatus.reading,
          minRating: 3.0,
        ),
      );
      expect(result.map((b) => b.id), ['1']);
    });
  });

  group('applyBookView - ソート', () {
    test('addedDesc: id の降順（≒ 追加日降順）', () {
      final books = [
        makeBook('1'),
        makeBook('3'),
        makeBook('2'),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(sort: BookSort.addedDesc),
      );
      expect(result.map((b) => b.id).toList(), ['3', '2', '1']);
    });

    test('ratingDesc: 評価が高い順、同点はタイトル昇順', () {
      final books = [
        makeBook('1', rating: 3.0, title: 'B'),
        makeBook('2', rating: 5.0, title: 'A'),
        makeBook('3', rating: 3.0, title: 'A'),
        makeBook('4', rating: 4.0, title: 'C'),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(sort: BookSort.ratingDesc),
      );
      expect(result.map((b) => b.title).toList(), ['A', 'C', 'A', 'B']);
    });

    test('titleAsc: タイトル昇順（Unicode code point 順）', () {
      // String.compareTo は Unicode code point 比較なので、ASCII / 数字 /
      // ひらがな / カタカナの順で並ぶ。実装の仕様としてここに固定。
      final books = [
        makeBook('1', title: 'Cherry'),
        makeBook('2', title: 'Apple'),
        makeBook('3', title: 'Banana'),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(sort: BookSort.titleAsc),
      );
      expect(
        result.map((b) => b.title).toList(),
        ['Apple', 'Banana', 'Cherry'],
      );
    });

    test('finishedDesc: 読了日が新しい順、未読了は末尾', () {
      final books = [
        makeBook('1', title: 'old', finishedAt: DateTime(2026, 1, 1)),
        makeBook('2', title: 'never'),
        makeBook('3', title: 'new', finishedAt: DateTime(2026, 5, 1)),
        makeBook('4', title: 'mid', finishedAt: DateTime(2026, 3, 1)),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(sort: BookSort.finishedDesc),
      );
      expect(
        result.map((b) => b.title).toList(),
        ['new', 'mid', 'old', 'never'],
      );
    });
  });

  group('applyBookView - フィルタ + ソート組み合わせ', () {
    test('読書中 ★3 以上を評価が高い順', () {
      final books = [
        makeBook('1', status: BookStatus.reading, rating: 4.0, title: 'B'),
        makeBook('2', status: BookStatus.reading, rating: 2.0, title: 'A'),
        makeBook('3', status: BookStatus.finished, rating: 5.0, title: 'C'),
        makeBook('4', status: BookStatus.reading, rating: 5.0, title: 'D'),
        makeBook('5', status: BookStatus.reading, rating: 3.0, title: 'E'),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(
          statusFilter: BookStatus.reading,
          minRating: 3.0,
          sort: BookSort.ratingDesc,
        ),
      );
      expect(result.map((b) => b.id).toList(), ['4', '1', '5']);
    });

    test('元のリストを破壊しない（pure function）', () {
      final original = [
        makeBook('1', rating: 1.0),
        makeBook('2', rating: 5.0),
      ];
      final snapshot = List<Book>.from(original);
      applyBookView(
        original,
        const BookViewSettings(sort: BookSort.ratingDesc),
      );
      expect(original.map((b) => b.id).toList(),
          snapshot.map((b) => b.id).toList());
    });
  });
}
