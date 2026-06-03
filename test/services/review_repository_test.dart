// ReviewRepository（hive_ce 経由の Review CRUD）の単体テスト。
//
// W5 のコアロジックテスト。BookRepository テストと同じくテンポラリ
// ディレクトリに hive ファイルを作成 → 破棄する形。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sample/models/review.dart';
import 'package:sample/services/review_repository.dart';

void main() {
  late Directory tmpDir;
  late Box<Map> box;
  late ReviewRepository repo;

  setUpAll(() async {
    tmpDir =
        await Directory.systemTemp.createTemp('hive_review_repo_test_');
    Hive.init(tmpDir.path);
  });

  setUp(() async {
    final boxName = 'reviews_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<Map>(boxName);
    repo = ReviewRepository.test(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await tmpDir.delete(recursive: true);
  });

  Review makeReview(String id, String bookId, {String? content}) {
    return Review(
      id: id,
      bookId: bookId,
      content: content ?? 'content of $id',
      createdAt: DateTime(2026, 5, int.parse(id.replaceAll(RegExp(r'\D'), ''))),
    );
  }

  group('ReviewRepository', () {
    test('初期状態は空', () {
      expect(repo.getByBookId('book-1'), isEmpty);
    });

    test('save した Review が getByBookId で取得できる', () async {
      final r = makeReview('1', 'book-1');
      await repo.save(r);

      final all = repo.getByBookId('book-1');
      expect(all, hasLength(1));
      expect(all.first.id, '1');
    });

    test('getByBookId は同じ Book.id のレビューだけを返す', () async {
      await repo.save(makeReview('1', 'book-1'));
      await repo.save(makeReview('2', 'book-1'));
      await repo.save(makeReview('3', 'book-2'));

      expect(repo.getByBookId('book-1'), hasLength(2));
      expect(repo.getByBookId('book-2'), hasLength(1));
      expect(repo.getByBookId('book-3'), isEmpty);
    });

    test('getByBookId は createdAt の降順で返す', () async {
      await repo.save(makeReview('1', 'book-1')); // 2026-05-01
      await repo.save(makeReview('3', 'book-1')); // 2026-05-03
      await repo.save(makeReview('2', 'book-1')); // 2026-05-02

      final list = repo.getByBookId('book-1');
      expect(list.map((r) => r.id).toList(), ['3', '2', '1']);
    });

    test('findById で 1 件取得（未登録なら null）', () async {
      await repo.save(makeReview('1', 'book-1'));

      expect(repo.findById('1'), isNotNull);
      expect(repo.findById('1')!.bookId, 'book-1');
      expect(repo.findById('99'), isNull);
    });

    test('save は同じ id だと上書き（upsert 動作）', () async {
      await repo.save(makeReview('1', 'book-1', content: 'old'));
      await repo.save(makeReview('1', 'book-1', content: 'new'));

      expect(repo.findById('1')!.content, 'new');
      expect(repo.getByBookId('book-1'), hasLength(1));
    });

    test('remove で削除できる', () async {
      await repo.save(makeReview('1', 'book-1'));
      expect(repo.findById('1'), isNotNull);

      await repo.remove('1');
      expect(repo.findById('1'), isNull);
    });

    test('removeByBookId で指定 Book のレビューだけ全削除', () async {
      await repo.save(makeReview('1', 'book-1'));
      await repo.save(makeReview('2', 'book-1'));
      await repo.save(makeReview('3', 'book-2'));

      await repo.removeByBookId('book-1');

      expect(repo.getByBookId('book-1'), isEmpty);
      expect(repo.getByBookId('book-2'), hasLength(1));
    });

    test('Review の全フィールドが toMap / fromMap で往復する', () async {
      final r = Review(
        id: 'r1',
        bookId: 'b1',
        content: '本文テスト 日本語',
        createdAt: DateTime(2026, 1, 1, 10, 30),
        updatedAt: DateTime(2026, 2, 1, 11, 0),
      );

      await repo.save(r);
      final retrieved = repo.findById('r1')!;

      expect(retrieved.id, 'r1');
      expect(retrieved.bookId, 'b1');
      expect(retrieved.content, '本文テスト 日本語');
      expect(retrieved.createdAt, DateTime(2026, 1, 1, 10, 30));
      expect(retrieved.updatedAt, DateTime(2026, 2, 1, 11, 0));
    });

    test('updatedAt が null でも往復する', () async {
      final r = makeReview('1', 'book-1');
      expect(r.updatedAt, isNull);

      await repo.save(r);
      final retrieved = repo.findById('1')!;
      expect(retrieved.updatedAt, isNull);
    });
  });
}
