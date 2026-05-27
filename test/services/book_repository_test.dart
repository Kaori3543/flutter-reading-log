// BookRepository（hive_ce 経由の Book CRUD）の単体テスト。
//
// W3 のコアロジックテスト。実際の hive box を使うが、テンポラリディレクトリ
// に作成・破棄するので CI / ローカルどちらでも動く。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/book_repository.dart';

void main() {
  late Directory tmpDir;
  late Box<Map> box;
  late BookRepository repo;

  setUpAll(() async {
    // テスト用のテンポラリディレクトリに hive ファイルを置く。
    tmpDir = await Directory.systemTemp.createTemp('hive_book_repo_test_');
    Hive.init(tmpDir.path);
  });

  setUp(() async {
    // 各テストで新しい box（衝突回避のためユニーク名）
    final boxName = 'books_${DateTime.now().microsecondsSinceEpoch}';
    box = await Hive.openBox<Map>(boxName);
    repo = BookRepository.test(box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  tearDownAll(() async {
    await tmpDir.delete(recursive: true);
  });

  group('BookRepository', () {
    test('初期状態は空', () {
      expect(repo.getAll(), isEmpty);
    });

    test('save した本が getAll で取得できる', () async {
      const book = Book(id: 'b1', title: 'Test Book', author: 'Author');
      await repo.save(book);

      final all = repo.getAll();
      expect(all, hasLength(1));
      expect(all.first.id, 'b1');
      expect(all.first.title, 'Test Book');
    });

    test('exists は登録済みなら true、未登録なら false', () async {
      const book = Book(id: 'b1', title: 'T', author: 'A');
      await repo.save(book);

      expect(repo.exists('b1'), isTrue);
      expect(repo.exists('b2'), isFalse);
    });

    test('findById で 1 件取得（未登録なら null）', () async {
      const book = Book(id: 'b1', title: 'Test', author: 'A');
      await repo.save(book);

      expect(repo.findById('b1'), isNotNull);
      expect(repo.findById('b1')!.title, 'Test');
      expect(repo.findById('b2'), isNull);
    });

    test('save は同じ id だと上書き（upsert 動作）', () async {
      const oldBook = Book(id: 'b1', title: 'Old', author: 'A');
      const newBook = Book(id: 'b1', title: 'New', author: 'A');

      await repo.save(oldBook);
      await repo.save(newBook);

      expect(repo.getAll(), hasLength(1));
      expect(repo.findById('b1')!.title, 'New');
    });

    test('remove で削除できる', () async {
      const book = Book(id: 'b1', title: 'T', author: 'A');
      await repo.save(book);
      expect(repo.getAll(), hasLength(1));

      await repo.remove('b1');
      expect(repo.getAll(), isEmpty);
      expect(repo.exists('b1'), isFalse);
    });

    test('clear で全件削除', () async {
      await repo.save(const Book(id: 'b1', title: 'A', author: 'X'));
      await repo.save(const Book(id: 'b2', title: 'B', author: 'Y'));
      expect(repo.getAll(), hasLength(2));

      await repo.clear();
      expect(repo.getAll(), isEmpty);
    });

    test('Book の全フィールドが toMap / fromMap で往復する', () async {
      final book = Book(
        id: 'b1',
        isbn: '978-4-12-345678-9',
        title: 'タイトル',
        author: '著者',
        publisher: '出版社',
        coverImageUrl: 'https://example.com/img.jpg',
        totalPages: 320,
        status: BookStatus.reading,
        currentPage: 100,
        rating: 4.5,
        startedAt: DateTime(2026, 1, 1),
        finishedAt: null,
      );

      await repo.save(book);
      final retrieved = repo.findById('b1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'b1');
      expect(retrieved.isbn, '978-4-12-345678-9');
      expect(retrieved.title, 'タイトル');
      expect(retrieved.author, '著者');
      expect(retrieved.publisher, '出版社');
      expect(retrieved.coverImageUrl, 'https://example.com/img.jpg');
      expect(retrieved.totalPages, 320);
      expect(retrieved.status, BookStatus.reading);
      expect(retrieved.currentPage, 100);
      expect(retrieved.rating, 4.5);
      expect(retrieved.startedAt, DateTime(2026, 1, 1));
      expect(retrieved.finishedAt, isNull);
    });
  });
}
