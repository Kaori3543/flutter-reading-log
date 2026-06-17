// 本棚の表示設定（フィルタ + ソート）を適用する純粋関数 `applyBookView` の
// 単体テスト。W6 で追加。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/providers/book_list_provider.dart';
import 'package:sample/providers/book_view_settings_provider.dart';

Book makeBook(
  String id, {
  String? title,
  String? author,
  String? publisher,
  String? genre,
  BookStatus status = BookStatus.wantToRead,
  double rating = 0.0,
  DateTime? finishedAt,
  bool isFavorite = false,
  List<String> tags = const [],
}) {
  return Book(
    id: id,
    title: title ?? 'title-$id',
    author: author ?? 'author-$id',
    publisher: publisher,
    genre: genre,
    status: status,
    rating: rating,
    finishedAt: finishedAt,
    isFavorite: isFavorite,
    tags: tags,
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

  group('applyBookView - ♡ お気に入りフィルタ（W11）', () {
    test('onlyFavorites = true は isFavorite の本だけ返す', () {
      final books = [
        makeBook('1', isFavorite: true),
        makeBook('2', isFavorite: false),
        makeBook('3', isFavorite: true),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(onlyFavorites: true),
      );
      expect(result.map((b) => b.id), unorderedEquals(['1', '3']));
    });

    test('onlyFavorites = false は全件通過', () {
      final books = [
        makeBook('1', isFavorite: true),
        makeBook('2', isFavorite: false),
      ];
      final result = applyBookView(books, const BookViewSettings());
      expect(result, hasLength(2));
    });
  });

  group('applyBookView - 全文検索クエリ（W11）', () {
    test('タイトルに部分一致する本だけを返す（大文字小文字無視）', () {
      final books = [
        makeBook('1', title: '夏の終わり'),
        makeBook('2', title: '冬の朝'),
        makeBook('3', title: '夏目漱石全集'),
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(searchQuery: '夏'),
      );
      expect(result.map((b) => b.id), unorderedEquals(['1', '3']));
    });

    test('著者・出版社・ジャンルも検索対象', () {
      final books = [
        makeBook('1', title: 'A', author: '村上 春樹'),
        makeBook('2', title: 'B', publisher: '岩波書店'),
        makeBook('3', title: 'C', genre: '小説'),
        makeBook('4', title: 'D', author: 'noise'),
      ];
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: '村上'))
            .map((b) => b.id),
        ['1'],
      );
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: '岩波'))
            .map((b) => b.id),
        ['2'],
      );
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: '小説'))
            .map((b) => b.id),
        ['3'],
      );
    });

    test('レビュー本文が reviewTextsByBookId 経由で検索対象になる', () {
      final books = [
        makeBook('1', title: 'A'),
        makeBook('2', title: 'B'),
        makeBook('3', title: 'C'),
      ];
      final reviews = {
        '1': '泣ける感動の物語',
        '2': 'ビジネスの基本',
      };
      final result = applyBookView(
        books,
        const BookViewSettings(searchQuery: '感動'),
        reviewTextsByBookId: reviews,
      );
      expect(result.map((b) => b.id), ['1']);
    });

    test('大文字小文字を区別しない', () {
      final books = [
        makeBook('1', title: 'Flutter Cookbook'),
      ];
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: 'flutter'))
            .map((b) => b.id),
        ['1'],
      );
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: 'COOKBOOK'))
            .map((b) => b.id),
        ['1'],
      );
    });

    test('前後の空白は無視', () {
      final books = [
        makeBook('1', title: 'hello world'),
      ];
      expect(
        applyBookView(books, const BookViewSettings(searchQuery: '  hello  '))
            .map((b) => b.id),
        ['1'],
      );
    });

    test('検索クエリが空文字なら全件通過', () {
      final books = [
        makeBook('1'),
        makeBook('2'),
      ];
      final result =
          applyBookView(books, const BookViewSettings(searchQuery: ''));
      expect(result, hasLength(2));
    });

    test('タグフィルタは OR 条件で適用される（W12）', () {
      final books = [
        makeBook('1', tags: ['仕事用']),
        makeBook('2', tags: ['2026年']),
        makeBook('3', tags: ['仕事用', '2026年']),
        makeBook('4', tags: ['教養']),
      ];
      // 仕事用 OR 2026年 → 1, 2, 3 が該当
      final result = applyBookView(
        books,
        const BookViewSettings(tagFilters: {'仕事用', '2026年'}),
      );
      expect(result.map((b) => b.id), unorderedEquals(['1', '2', '3']));
    });

    test('タグフィルタが空 Set ならフィルタなし（W12）', () {
      final books = [
        makeBook('1', tags: ['仕事用']),
        makeBook('2'),
      ];
      final result = applyBookView(books, const BookViewSettings());
      expect(result, hasLength(2));
    });

    test('検索 + ステータス + 評価 + ♡ は AND 条件で適用', () {
      final books = [
        makeBook('1',
            title: '夏の本',
            status: BookStatus.finished,
            rating: 5.0,
            isFavorite: true),
        makeBook('2',
            title: '夏の本',
            status: BookStatus.finished,
            rating: 5.0,
            isFavorite: false), // 除外（♡なし）
        makeBook('3',
            title: '夏の本',
            status: BookStatus.reading,
            rating: 5.0,
            isFavorite: true), // 除外（読書中）
        makeBook('4',
            title: '夏の本',
            status: BookStatus.finished,
            rating: 3.0,
            isFavorite: true), // 除外（評価低）
        makeBook('5',
            title: '冬の本',
            status: BookStatus.finished,
            rating: 5.0,
            isFavorite: true), // 除外（検索ミス）
      ];
      final result = applyBookView(
        books,
        const BookViewSettings(
          searchQuery: '夏',
          statusFilter: BookStatus.finished,
          minRating: 4.0,
          onlyFavorites: true,
        ),
      );
      expect(result.map((b) => b.id), ['1']);
    });
  });
}
