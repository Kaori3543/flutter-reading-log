// リマインダー集計関数 collectReminders の単体テスト（W9）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/reminders.dart';

Book wantToRead(String id, {DateTime? addedAt}) => Book(
      id: id,
      title: 'want-$id',
      author: 'a',
      status: BookStatus.wantToRead,
      addedAt: addedAt,
    );

Book reading(String id, {DateTime? startedAt}) => Book(
      id: id,
      title: 'read-$id',
      author: 'a',
      status: BookStatus.reading,
      startedAt: startedAt,
    );

Book finished(String id) => Book(
      id: id,
      title: 'fin-$id',
      author: 'a',
      status: BookStatus.finished,
    );

void main() {
  final now = DateTime(2026, 6, 1);

  group('collectReminders - R6 読みかけ放置', () {
    test('startedAt から 30 日以上経過した読書中の本だけ拾う', () {
      final books = [
        reading('a', startedAt: now.subtract(const Duration(days: 60))), // 該当
        reading('b', startedAt: now.subtract(const Duration(days: 30))), // 該当（境界）
        reading('c', startedAt: now.subtract(const Duration(days: 5))), // 除外
        reading('d', startedAt: null), // 除外
      ];

      final r = collectReminders(books, now);
      expect(r.stalledReading.map((b) => b.id), ['a', 'b']);
    });

    test('読みたい・読了の本は対象外', () {
      final books = [
        wantToRead('a', addedAt: now.subtract(const Duration(days: 365))),
        finished('b'),
        reading('c', startedAt: now.subtract(const Duration(days: 60))),
      ];

      final r = collectReminders(books, now);
      expect(r.stalledReading.map((b) => b.id), ['c']);
    });

    test('startedAt の昇順（古い順）で返る', () {
      final books = [
        reading('newer', startedAt: now.subtract(const Duration(days: 40))),
        reading('older', startedAt: now.subtract(const Duration(days: 120))),
        reading('mid', startedAt: now.subtract(const Duration(days: 80))),
      ];

      final r = collectReminders(books, now);
      expect(r.stalledReading.map((b) => b.id).toList(),
          ['older', 'mid', 'newer']);
    });
  });

  group('collectReminders - R5 積読放置', () {
    test('addedAt から 90 日以上経過した「読みたい」本だけ拾う', () {
      final books = [
        wantToRead('a', addedAt: now.subtract(const Duration(days: 180))),
        wantToRead('b', addedAt: now.subtract(const Duration(days: 90))), // 境界
        wantToRead('c', addedAt: now.subtract(const Duration(days: 30))),
        wantToRead('d', addedAt: null), // 既存本扱い、除外
      ];

      final r = collectReminders(books, now);
      expect(r.stalledWantToRead.map((b) => b.id), ['a', 'b']);
    });

    test('読書中・読了の本は対象外', () {
      final books = [
        wantToRead('a', addedAt: now.subtract(const Duration(days: 120))),
        reading('b', startedAt: now.subtract(const Duration(days: 365))),
        finished('c'),
      ];

      final r = collectReminders(books, now);
      expect(r.stalledWantToRead.map((b) => b.id), ['a']);
    });

    test('addedAt の昇順（古い順）で返る', () {
      final books = [
        wantToRead('newer', addedAt: now.subtract(const Duration(days: 100))),
        wantToRead('older', addedAt: now.subtract(const Duration(days: 300))),
        wantToRead('mid', addedAt: now.subtract(const Duration(days: 200))),
      ];

      final r = collectReminders(books, now);
      expect(r.stalledWantToRead.map((b) => b.id).toList(),
          ['older', 'mid', 'newer']);
    });
  });

  group('collectReminders - isEmpty', () {
    test('該当本ゼロなら isEmpty が true', () {
      final r = collectReminders([], now);
      expect(r.isEmpty, isTrue);
      expect(r.stalledReading, isEmpty);
      expect(r.stalledWantToRead, isEmpty);
    });

    test('片方だけ該当があれば isEmpty は false', () {
      final books = [
        reading('a', startedAt: now.subtract(const Duration(days: 60))),
      ];
      final r = collectReminders(books, now);
      expect(r.isEmpty, isFalse);
      expect(r.stalledReading, hasLength(1));
      expect(r.stalledWantToRead, isEmpty);
    });
  });
}
