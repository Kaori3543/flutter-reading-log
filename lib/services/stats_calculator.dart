/// 統計画面（W7）で使う集計ロジック。
///
/// すべて純粋関数として実装し、本リスト + 期間設定 + 現在時刻を受け取って
/// 集計結果のスナップショットを返す。テストしやすく、UI 層からは StatsResult
/// だけを受け取って描画する。
///
/// 集計対象: BookStatus.finished かつ finishedAt が非 null の本だけ。
/// 「読みたい・読書中」は含めない（W7 のジャンル選択 G1 / 集計対象選択での確定）。
library;

import '../models/book.dart';

/// 統計集計の期間種別。
enum StatsPeriod {
  /// 直近 6 ヶ月。
  last6Months,

  /// 直近 1 年。
  last1Year,

  /// 全期間（finishedAt がある全ての本）。
  allTime,
}

extension StatsPeriodLabel on StatsPeriod {
  String get label {
    switch (this) {
      case StatsPeriod.last6Months:
        return '直近 6 ヶ月';
      case StatsPeriod.last1Year:
        return '直近 1 年';
      case StatsPeriod.allTime:
        return '全期間';
    }
  }
}

/// 月ごとの完読冊数。
class MonthlyCount {
  /// 月の 1 日 0:00 で正規化された日時。
  final DateTime month;
  final int count;
  const MonthlyCount({required this.month, required this.count});
}

/// ジャンルごとの完読冊数。
class GenreCount {
  final String genre;
  final int count;
  const GenreCount({required this.genre, required this.count});
}

/// 統計画面が描画に使う集計結果スナップショット。
class StatsResult {
  /// 期間内の総完読冊数。
  final int totalFinished;

  /// 月別冊数（古い順）。期間内の全ての月（読了 0 件の月も 0 で含む）。
  final List<MonthlyCount> monthly;

  /// 累計推移（古い順）。各月末時点での累計完読冊数。
  final List<MonthlyCount> cumulative;

  /// ジャンル別冊数（多い順）。genre が null の本は除外。
  final List<GenreCount> genres;

  /// 直近 30 日（now を含む）で完読した冊数。読書ペースの目安。
  final int recent30DaysCount;

  const StatsResult({
    required this.totalFinished,
    required this.monthly,
    required this.cumulative,
    required this.genres,
    required this.recent30DaysCount,
  });

  /// 期間内に完読本が 1 件も無い状態。
  bool get isEmpty => totalFinished == 0;
}

/// 統計の集計エントリポイント。
///
/// [books] のうち BookStatus.finished かつ finishedAt が非 null の本のみを
/// 対象に、[period] の範囲で絞り込んでから集計する。
/// [now] はテスト時の固定時刻のために引数化（本番では DateTime.now() を渡す）。
StatsResult calculateStats(
  List<Book> books,
  StatsPeriod period,
  DateTime now,
) {
  // 1. 完読本だけに絞る。
  final finishedBooks = books
      .where((b) => b.status == BookStatus.finished && b.finishedAt != null)
      .toList();

  // 2. 期間の開始月（範囲の最古月）を決める。
  //    last6Months: 5 ヶ月前の 1 日（今月含めて 6 ヶ月分）
  //    last1Year:   11 ヶ月前の 1 日（今月含めて 12 ヶ月分）
  //    allTime:     最古の finishedAt が属する月の 1 日
  final currentMonth = DateTime(now.year, now.month, 1);

  DateTime startMonth;
  switch (period) {
    case StatsPeriod.last6Months:
      startMonth = _addMonths(currentMonth, -5);
      break;
    case StatsPeriod.last1Year:
      startMonth = _addMonths(currentMonth, -11);
      break;
    case StatsPeriod.allTime:
      if (finishedBooks.isEmpty) {
        startMonth = currentMonth;
      } else {
        final earliest = finishedBooks
            .map((b) => b.finishedAt!)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        startMonth = DateTime(earliest.year, earliest.month, 1);
      }
      break;
  }

  // 3. 期間でフィルタ。
  final inPeriod = finishedBooks
      .where((b) => !b.finishedAt!.isBefore(startMonth))
      .toList();

  // 4. 月ごとの冊数を集計（期間内の全ての月をゼロ埋めで含める）。
  final monthly = <MonthlyCount>[];
  DateTime cursor = startMonth;
  while (!cursor.isAfter(currentMonth)) {
    final c = inPeriod.where((b) {
      final f = b.finishedAt!;
      return f.year == cursor.year && f.month == cursor.month;
    }).length;
    monthly.add(MonthlyCount(month: cursor, count: c));
    cursor = _addMonths(cursor, 1);
  }

  // 5. 累計推移（月ごとに 1〜N の累計を取る）。
  final cumulative = <MonthlyCount>[];
  int running = 0;
  for (final m in monthly) {
    running += m.count;
    cumulative.add(MonthlyCount(month: m.month, count: running));
  }

  // 6. ジャンル別集計（期間内・genre 非 null のみ・多い順）。
  final genreMap = <String, int>{};
  for (final b in inPeriod) {
    final g = b.genre;
    if (g == null || g.isEmpty) continue;
    genreMap[g] = (genreMap[g] ?? 0) + 1;
  }
  final genres = genreMap.entries
      .map((e) => GenreCount(genre: e.key, count: e.value))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.genre.compareTo(b.genre);
    });

  // 7. 直近 30 日の冊数。
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final recent30 = finishedBooks
      .where((b) => !b.finishedAt!.isBefore(thirtyDaysAgo))
      .length;

  return StatsResult(
    totalFinished: inPeriod.length,
    monthly: monthly,
    cumulative: cumulative,
    genres: genres,
    recent30DaysCount: recent30,
  );
}

/// DateTime に月数を加算する（負値で過去方向）。
/// 例: 2026/03/01 + 2 = 2026/05/01、2026/01/01 + (-3) = 2025/10/01
DateTime _addMonths(DateTime base, int months) {
  final m = base.month + months;
  final yearShift = (m - 1) ~/ 12 - (m - 1 < 0 ? 1 : 0);
  final newMonth = ((m - 1) % 12 + 12) % 12 + 1;
  return DateTime(base.year + yearShift, newMonth, 1);
}
