/// ホームタブのリマインダー集計（W9 で新規追加）。
///
/// 「読みたい」状態が長く放置されている本（積読）や、「読書中」のまま
/// 進捗が止まっている本を検出する純粋関数。
/// UI 層からは [collectReminders] を呼ぶだけで両方の結果が返る。
library;

import '../models/book.dart';

/// 積読・読みかけリマインダーの結果スナップショット。
class RemindersResult {
  /// 「読書中」のまま [stalledReadingThreshold] 以上経過した本（R6）。
  final List<Book> stalledReading;

  /// 「読みたい」のまま [stalledWantToReadThreshold] 以上経過した本（R5）。
  final List<Book> stalledWantToRead;

  const RemindersResult({
    required this.stalledReading,
    required this.stalledWantToRead,
  });

  bool get isEmpty =>
      stalledReading.isEmpty && stalledWantToRead.isEmpty;
}

/// R6 のしきい値: startedAt から 30 日以上進んでいない本を「読みかけ放置」と判定。
const Duration stalledReadingThreshold = Duration(days: 30);

/// R5 のしきい値: 本棚に追加してから 90 日以上経った読みたい本を「積読放置」と判定。
const Duration stalledWantToReadThreshold = Duration(days: 90);

/// 各リマインダー条件に該当する本をまとめて返す純粋関数。
///
/// - 「読みかけ放置」（R6）: status == reading かつ startedAt が
///   [stalledReadingThreshold] 以上前。startedAt が null の本は除外。
///   読了日が新しい（取り組み直したばかり）の本を末尾に並べたいので、
///   startedAt の昇順（古い順）で返す。
/// - 「積読放置」（R5）: status == wantToRead かつ addedAt が
///   [stalledWantToReadThreshold] 以上前。addedAt が null の本（W9 以前に
///   登録された本）は除外。addedAt の昇順（古い順）で返す。
RemindersResult collectReminders(List<Book> books, DateTime now) {
  final stalledReading = <Book>[];
  final stalledWantToRead = <Book>[];

  for (final b in books) {
    if (b.status == BookStatus.reading) {
      final started = b.startedAt;
      if (started != null && now.difference(started) >= stalledReadingThreshold) {
        stalledReading.add(b);
      }
    } else if (b.status == BookStatus.wantToRead) {
      final added = b.addedAt;
      if (added != null && now.difference(added) >= stalledWantToReadThreshold) {
        stalledWantToRead.add(b);
      }
    }
  }

  // 古い順に並べる（一番手がついていない本を先頭に）
  stalledReading.sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
  stalledWantToRead.sort((a, b) => a.addedAt!.compareTo(b.addedAt!));

  return RemindersResult(
    stalledReading: stalledReading,
    stalledWantToRead: stalledWantToRead,
  );
}
