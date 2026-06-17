// 統計集計関数 calculateStats の単体テスト（W7）。
//
// テスト方針:
//   - 「現在時刻」は固定値 2026/06/01 を now として渡す。
//   - 期間ごとの startMonth、月別ゼロ埋め、累計、ジャンル集計、recent30 を確認。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/stats_calculator.dart';

Book makeFinished(
  String id, {
  required DateTime finishedAt,
  String? genre,
}) {
  return Book(
    id: id,
    title: 'title-$id',
    author: 'author',
    status: BookStatus.finished,
    finishedAt: finishedAt,
    genre: genre,
  );
}

void main() {
  final now = DateTime(2026, 6, 1);

  group('calculateStats - 集計対象フィルタ', () {
    test('finished ステータス かつ finishedAt 非 null の本だけ集計する', () {
      final books = [
        makeFinished('1', finishedAt: DateTime(2026, 5, 15)),
        // 読みたい本は除外
        Book(id: '2', title: 't', author: 'a', status: BookStatus.wantToRead),
        // 読書中の本も除外
        Book(id: '3', title: 't', author: 'a', status: BookStatus.reading),
        // finished だが finishedAt が null も除外
        Book(id: '4', title: 't', author: 'a', status: BookStatus.finished),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      expect(result.totalFinished, 1);
    });

    test('完読本ゼロなら isEmpty が true', () {
      final result = calculateStats([], StatsPeriod.last6Months, now);
      expect(result.isEmpty, isTrue);
      expect(result.totalFinished, 0);
    });
  });

  group('calculateStats - 期間フィルタ', () {
    test('last6Months: 5 ヶ月前の 1 日以降の本のみカウント', () {
      final books = [
        makeFinished('old', finishedAt: DateTime(2025, 12, 31)),
        makeFinished('edge', finishedAt: DateTime(2026, 1, 1)),
        makeFinished('mid', finishedAt: DateTime(2026, 4, 15)),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      // 範囲: 2026/01 〜 2026/06 → edge と mid が対象
      expect(result.totalFinished, 2);
    });

    test('last1Year: 11 ヶ月前の 1 日以降の本のみカウント', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2025, 6, 30)),
        makeFinished('b', finishedAt: DateTime(2025, 7, 1)),
        makeFinished('c', finishedAt: DateTime(2026, 5, 1)),
      ];

      final result = calculateStats(books, StatsPeriod.last1Year, now);
      // 範囲: 2025/07 〜 2026/06 → b と c が対象
      expect(result.totalFinished, 2);
    });

    test('allTime: 全ての完読本をカウント', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2020, 1, 1)),
        makeFinished('b', finishedAt: DateTime(2025, 6, 1)),
        makeFinished('c', finishedAt: DateTime(2026, 5, 1)),
      ];

      final result = calculateStats(books, StatsPeriod.allTime, now);
      expect(result.totalFinished, 3);
    });
  });

  group('calculateStats - 月別集計', () {
    test('last6Months は 6 ヶ月分のデータポイントを返す（0 件月もゼロ埋め）', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 4, 10)),
        makeFinished('b', finishedAt: DateTime(2026, 4, 20)),
        makeFinished('c', finishedAt: DateTime(2026, 6, 1)),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      expect(result.monthly, hasLength(6));

      // 最古月: 2026/01、最新月: 2026/06
      expect(result.monthly.first.month, DateTime(2026, 1, 1));
      expect(result.monthly.last.month, DateTime(2026, 6, 1));

      // 4 月 = 2 件、6 月 = 1 件、他は 0 件
      expect(result.monthly[3].count, 2); // 2026/04
      expect(result.monthly[5].count, 1); // 2026/06
      expect(result.monthly[0].count, 0); // 2026/01
      expect(result.monthly[1].count, 0); // 2026/02
    });

    test('累計が単調増加で正しく積み上がる', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 3, 1)),
        makeFinished('b', finishedAt: DateTime(2026, 3, 15)),
        makeFinished('c', finishedAt: DateTime(2026, 5, 1)),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      // 2026/01: 0, 02: 0, 03: 2, 04: 2, 05: 3, 06: 3
      expect(result.cumulative.map((m) => m.count).toList(), [0, 0, 2, 2, 3, 3]);
    });
  });

  group('calculateStats - 年またぎ', () {
    test('last6Months で年をまたいでも月別が正しく繋がる', () {
      // now = 2026/01/15 を想定
      final newYear = DateTime(2026, 1, 15);
      final books = [
        makeFinished('a', finishedAt: DateTime(2025, 9, 10)),
        makeFinished('b', finishedAt: DateTime(2025, 12, 31)),
        makeFinished('c', finishedAt: DateTime(2026, 1, 5)),
      ];

      final result =
          calculateStats(books, StatsPeriod.last6Months, newYear);
      expect(result.monthly, hasLength(6));
      // 範囲: 2025/08 〜 2026/01
      expect(result.monthly.first.month, DateTime(2025, 8, 1));
      expect(result.monthly.last.month, DateTime(2026, 1, 1));
      expect(result.totalFinished, 3);
    });
  });

  group('calculateStats - ジャンル別', () {
    test('ジャンル別集計が多い順で返る、null は除外', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 5, 1), genre: '小説'),
        makeFinished('b', finishedAt: DateTime(2026, 5, 2), genre: '小説'),
        makeFinished('c', finishedAt: DateTime(2026, 5, 3), genre: '技術書'),
        makeFinished('d', finishedAt: DateTime(2026, 5, 4), genre: null),
        makeFinished('e', finishedAt: DateTime(2026, 5, 5), genre: '小説'),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      expect(result.genres, hasLength(2));
      expect(result.genres[0].genre, '小説');
      expect(result.genres[0].count, 3);
      expect(result.genres[1].genre, '技術書');
      expect(result.genres[1].count, 1);
    });

    test('同じ件数のジャンルはジャンル名昇順で安定化', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 5, 1), genre: 'C'),
        makeFinished('b', finishedAt: DateTime(2026, 5, 2), genre: 'A'),
        makeFinished('c', finishedAt: DateTime(2026, 5, 3), genre: 'B'),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      expect(result.genres.map((g) => g.genre).toList(), ['A', 'B', 'C']);
    });
  });

  group('calculateStats - 直近 30 日', () {
    test('now を含む 30 日以内の完読本だけ recent30 にカウント', () {
      // now = 2026/06/01 → 31 日前は 2026/05/02
      final books = [
        makeFinished('within', finishedAt: DateTime(2026, 5, 15)),
        makeFinished('within2', finishedAt: DateTime(2026, 5, 31)),
        makeFinished('out', finishedAt: DateTime(2026, 4, 1)),
      ];

      final result = calculateStats(books, StatsPeriod.last6Months, now);
      expect(result.recent30DaysCount, 2);
    });

    test('recent30 は期間フィルタの影響を受けない（全データから集計）', () {
      // last6Months 対象外（2025/06/15）でも、now から 30 日以内なら除外される
      // ここでは「対象外で 30 日以前」と「対象外で 30 日以内」を混ぜる
      // → そもそも 30 日以内なら期間 6 ヶ月にも入るが、念のため allTime と
      // last6Months で値が同じであることを確認
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 5, 15)),
        makeFinished('b', finishedAt: DateTime(2025, 1, 1)),
      ];

      final r6 = calculateStats(books, StatsPeriod.last6Months, now);
      final rAll = calculateStats(books, StatsPeriod.allTime, now);
      expect(r6.recent30DaysCount, 1);
      expect(rAll.recent30DaysCount, 1);
    });
  });

  group('calculateStats - 今月の完読冊数（W9）', () {
    test('now と同じ年月の finishedAt の本だけ thisMonthCount に集計', () {
      // now = 2026/06/01
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 6, 1)),
        makeFinished('b', finishedAt: DateTime(2026, 6, 25)),
        makeFinished('c', finishedAt: DateTime(2026, 5, 30)),
        makeFinished('d', finishedAt: DateTime(2025, 6, 1)),
      ];
      final r = calculateStats(books, StatsPeriod.last6Months, now);
      expect(r.thisMonthCount, 2);
    });

    test('期間フィルタの影響を受けない（全データから今月分を集計）', () {
      final books = [
        makeFinished('a', finishedAt: DateTime(2026, 6, 15)),
      ];
      final r6 = calculateStats(books, StatsPeriod.last6Months, now);
      final rAll = calculateStats(books, StatsPeriod.allTime, now);
      expect(r6.thisMonthCount, 1);
      expect(rAll.thisMonthCount, 1);
    });
  });

  group('calculateStats - お気に入り著者ランキング（W9 案 V）', () {
    Book favorite(String id, String author) => Book(
          id: id,
          title: 't-$id',
          author: author,
          status: BookStatus.finished,
          finishedAt: DateTime(2026, 5, 1),
          rating: 4.5,
          isFavoriteAuthor: true,
        );

    test('isFavoriteAuthor = true の本で著者ごとに集計（多い順）', () {
      final books = [
        favorite('1', 'A'),
        favorite('2', 'A'),
        favorite('3', 'B'),
        // フラグ OFF の高評価本は集計対象外
        Book(
          id: '4',
          title: 'no-fav',
          author: 'C',
          status: BookStatus.finished,
          finishedAt: DateTime(2026, 5, 1),
          rating: 5.0,
        ),
      ];
      final r = calculateStats(books, StatsPeriod.allTime, now);
      expect(r.favoriteAuthors, hasLength(2));
      expect(r.favoriteAuthors[0].author, 'A');
      expect(r.favoriteAuthors[0].favoriteCount, 2);
      expect(r.favoriteAuthors[1].author, 'B');
    });

    test('期間フィルタの影響を受けない（全期間で集計）', () {
      final books = [
        favorite('1', 'A'),
        Book(
          id: '2',
          title: 'old',
          author: 'A',
          status: BookStatus.finished,
          finishedAt: DateTime(2020, 1, 1),
          rating: 5.0,
          isFavoriteAuthor: true,
        ),
      ];
      // last6Months にしても A 著者 2 件として集計される
      final r6 = calculateStats(books, StatsPeriod.last6Months, now);
      expect(r6.favoriteAuthors.first.favoriteCount, 2);
    });
  });
}
