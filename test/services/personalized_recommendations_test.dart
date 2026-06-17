// パーソナライズ集計関数のテスト（W9）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/personalized_recommendations.dart';

Book book(
  String id, {
  required String author,
  BookStatus status = BookStatus.finished,
  double rating = 0.0,
  String? genre,
  String? genreId,
  bool isFavoriteAuthor = false,
}) =>
    Book(
      id: id,
      title: 't-$id',
      author: author,
      status: status,
      rating: rating,
      genre: genre,
      genreId: genreId,
      isFavoriteAuthor: isFavoriteAuthor,
    );

void main() {
  group('primaryAuthor', () {
    test('"/" 区切りで最初のセグメントを返す（著者 + 翻訳者の連結対応）', () {
      expect(primaryAuthor('ビル・パーキンス/児島 修'), 'ビル・パーキンス');
      expect(primaryAuthor('村上 春樹'), '村上 春樹');
    });

    test('全角スラッシュ／・読点／半角カンマも区切り文字として扱う', () {
      expect(primaryAuthor('著者A／訳者B'), '著者A');
      expect(primaryAuthor('著者A、訳者B'), '著者A');
      expect(primaryAuthor('著者A,訳者B'), '著者A');
    });

    test('前後の空白は除去される', () {
      expect(primaryAuthor('  村上 春樹  '), '村上 春樹');
      expect(primaryAuthor(' 著者A / 訳者B '), '著者A');
    });

    test('空文字はそのまま返す', () {
      expect(primaryAuthor(''), '');
    });
  });

  group('collectFavoriteAuthors（W9 案 V: isFavoriteAuthor フラグベース）', () {
    test('isFavoriteAuthor = true の本だけ集計する', () {
      final books = [
        book('1', author: 'A', isFavoriteAuthor: true),
        book('2', author: 'A', isFavoriteAuthor: true),
        book('3', author: 'B', isFavoriteAuthor: true),
        // フラグ OFF は除外（評価が高くても）
        book('4', author: 'C', rating: 5.0, isFavoriteAuthor: false),
      ];

      final result = collectFavoriteAuthors(books);
      expect(result, hasLength(2));
      expect(result[0].author, 'A');
      expect(result[0].favoriteCount, 2);
      expect(result[1].author, 'B');
      expect(result[1].favoriteCount, 1);
    });

    test('読書中・読みたい状態でも isFavoriteAuthor が true なら集計される', () {
      // 案 V ではユーザーの意思が優先。ステータスは問わない。
      final books = [
        book('1',
            author: 'A',
            status: BookStatus.wantToRead,
            isFavoriteAuthor: true),
        book('2',
            author: 'A',
            status: BookStatus.reading,
            isFavoriteAuthor: true),
        book('3', author: 'A', isFavoriteAuthor: true),
      ];
      final r = collectFavoriteAuthors(books);
      expect(r.first.favoriteCount, 3);
    });

    test('多い順、同点は著者名昇順（Unicode code point 順）で安定化', () {
      final books = [
        book('1', author: '川端', isFavoriteAuthor: true),
        book('2', author: '夏目', isFavoriteAuthor: true),
        book('3', author: '夏目', isFavoriteAuthor: true),
        book('4', author: '芥川', isFavoriteAuthor: true),
        book('5', author: '川端', isFavoriteAuthor: true),
      ];

      final result = collectFavoriteAuthors(books);
      expect(result.map((s) => s.author).toList(), ['夏目', '川端', '芥川']);
    });

    test('平均評価は rating > 0 の本だけで計算される（評価無しは無視）', () {
      final books = [
        book('1', author: 'X', rating: 4.0, isFavoriteAuthor: true),
        book('2', author: 'X', rating: 5.0, isFavoriteAuthor: true),
        // 評価無し ON → カウントに含むが平均からは除外
        book('3', author: 'X', rating: 0.0, isFavoriteAuthor: true),
      ];
      final r = collectFavoriteAuthors(books);
      expect(r.first.favoriteCount, 3);
      expect(r.first.averageFavoriteRating, closeTo(4.5, 0.01));
    });

    test('該当ゼロは空配列', () {
      final books = [
        book('1', author: 'A', rating: 5.0), // フラグ OFF
        book('2', author: 'B', isFavoriteAuthor: false),
      ];
      expect(collectFavoriteAuthors(books), isEmpty);
    });

    test('翻訳者違いの同じ主著者は合算される', () {
      final books = [
        book('1', author: 'ビル・パーキンス/児島 修', isFavoriteAuthor: true),
        book('2', author: 'ビル・パーキンス/別の訳者', isFavoriteAuthor: true),
        book('3', author: '別の著者/誰か', isFavoriteAuthor: true),
      ];
      final result = collectFavoriteAuthors(books);
      expect(result, hasLength(2));
      expect(result.first.author, 'ビル・パーキンス');
      expect(result.first.favoriteCount, 2);
    });
  });

  group('collectFavoriteGenres / collectFavoriteGenreIds', () {
    test('完読本のうち genre 非 null の本を集計、多い順', () {
      final books = [
        book('1', author: 'A', genre: '小説', genreId: '001004001'),
        book('2', author: 'B', genre: '小説', genreId: '001004001'),
        book('3', author: 'C', genre: 'ビジネス', genreId: '001006001'),
        // 読みたい状態 → 除外
        book('4',
            author: 'D',
            genre: '小説',
            genreId: '001004001',
            status: BookStatus.wantToRead),
        // genre/genreId が null → 除外
        book('5', author: 'E'),
      ];

      expect(collectFavoriteGenres(books), ['小説', 'ビジネス']);
      expect(collectFavoriteGenreIds(books), ['001004001', '001006001']);
    });

    test('該当ゼロは空配列', () {
      expect(collectFavoriteGenres([]), isEmpty);
      expect(collectFavoriteGenreIds([]), isEmpty);
    });

    test('同件数のジャンルは名前/ID 昇順で安定化', () {
      final books = [
        book('1', author: 'A', genre: 'C', genreId: '003'),
        book('2', author: 'B', genre: 'A', genreId: '001'),
        book('3', author: 'C', genre: 'B', genreId: '002'),
      ];
      expect(collectFavoriteGenres(books), ['A', 'B', 'C']);
      expect(collectFavoriteGenreIds(books), ['001', '002', '003']);
    });
  });
}
