// タグ集計関数 + テンプレート定義のテスト（W12）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/tag_calculator.dart';

Book tagged(String id, List<String> tags) => Book(
      id: id,
      title: 't-$id',
      author: 'a',
      tags: tags,
    );

void main() {
  group('collectAllTags', () {
    test('全本のタグを集計して冊数の多い順で返す', () {
      final books = [
        tagged('1', ['仕事用', '2026年']),
        tagged('2', ['仕事用']),
        tagged('3', ['仕事用', '教養']),
        tagged('4', ['2026年']),
      ];
      final result = collectAllTags(books);
      expect(result, hasLength(3));
      expect(result[0].name, '仕事用');
      expect(result[0].count, 3);
      expect(result[1].name, '2026年');
      expect(result[1].count, 2);
      expect(result[2].name, '教養');
      expect(result[2].count, 1);
    });

    test('同点はタグ名昇順で安定化', () {
      final books = [
        tagged('1', ['C']),
        tagged('2', ['A']),
        tagged('3', ['B']),
      ];
      final result = collectAllTags(books);
      expect(result.map((t) => t.name).toList(), ['A', 'B', 'C']);
    });

    test('タグなしの本は無視', () {
      final books = [
        tagged('1', []),
        tagged('2', ['仕事']),
      ];
      final result = collectAllTags(books);
      expect(result, hasLength(1));
      expect(result.first.name, '仕事');
    });

    test('空文字のタグは除外', () {
      final books = [
        tagged('1', ['', '仕事', '']),
      ];
      final result = collectAllTags(books);
      expect(result, hasLength(1));
      expect(result.first.name, '仕事');
    });

    test('該当ゼロは空配列', () {
      expect(collectAllTags([]), isEmpty);
    });
  });

  group('collectBooksByTag', () {
    test('指定タグを持つ本だけ返す', () {
      final books = [
        tagged('1', ['仕事', '2026年']),
        tagged('2', ['仕事']),
        tagged('3', ['2026年']),
      ];
      expect(
        collectBooksByTag(books, '仕事').map((b) => b.id).toList(),
        ['1', '2'],
      );
      expect(
        collectBooksByTag(books, '2026年').map((b) => b.id).toList(),
        ['1', '3'],
      );
    });

    test('該当なしは空配列', () {
      final books = [tagged('1', ['仕事'])];
      expect(collectBooksByTag(books, '無いタグ'), isEmpty);
    });
  });

  group('buildTagTemplates', () {
    test('現在年と前年のタグを含む', () {
      final now = DateTime(2026, 6, 1);
      final templates = buildTagTemplates(now);
      expect(templates, contains('2026 年に読んだ'));
      expect(templates, contains('2025 年に読んだ'));
    });

    test('固定テンプレートを含む', () {
      final now = DateTime(2026);
      final templates = buildTagTemplates(now);
      expect(templates, containsAll(['仕事用', '再読リスト', 'お気に入り', '教養']));
    });
  });
}
