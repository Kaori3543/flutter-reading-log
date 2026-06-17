/// 本棚のタグ集計（W12 で新規追加）。
///
/// タグは `Book.tags`（`List<String>`）に分散して保存されているため、
/// ライブラリタブやタグ管理画面で「全タグ一覧 + 各タグの本数」が必要なときに
/// 本リストから集計する純粋関数群を提供する。
library;

import '../models/book.dart';

/// タグごとの本の冊数。
class TagCount {
  final String name;
  final int count;
  const TagCount({required this.name, required this.count});
}

/// 全本のタグを集計して、(タグ名, 冊数) のリストを返す。
///
/// 並び順: 冊数の多い順 → 同点はタグ名昇順で安定化。
/// 空文字のタグは除外。
List<TagCount> collectAllTags(List<Book> books) {
  final counter = <String, int>{};
  for (final b in books) {
    for (final t in b.tags) {
      if (t.isEmpty) continue;
      counter[t] = (counter[t] ?? 0) + 1;
    }
  }
  final list = counter.entries
      .map((e) => TagCount(name: e.key, count: e.value))
      .toList()
    ..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return a.name.compareTo(b.name);
    });
  return list;
}

/// 指定したタグを持つ本だけを返す。並び順は元のリストを尊重する。
List<Book> collectBooksByTag(List<Book> books, String tag) {
  return books.where((b) => b.tags.contains(tag)).toList(growable: false);
}

/// テンプレートタグの定義（W12 で導入）。
///
/// ユーザーがタグ管理画面の「テンプレートから追加」で 1 タップで作成できる
/// プリセット集。年テンプレートは [now] の年を埋め込んで返す。
///
/// テンプレート選択 → そのタグ名で空タグを作る、というのは難しい
/// （タグは本に紐づくフィールドなので「空のタグ」は概念的に存在しない）。
/// なので「テンプレートから追加」は実用上、ユーザーが本にそのタグを付ける
/// 際の **候補リスト** として機能する。タグ作成ダイアログで提示する。
List<String> buildTagTemplates(DateTime now) {
  final year = now.year;
  return [
    '$year 年に読んだ',
    '${year - 1} 年に読んだ',
    '仕事用',
    '再読リスト',
    'お気に入り',
    '教養',
    '勉強中',
  ];
}
