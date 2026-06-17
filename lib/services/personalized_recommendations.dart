/// ホームタブの「あなたへのおすすめ」のための、ユーザー嗜好の抽出（W9）。
///
/// 完読本かつ高評価（★4.0 以上）の本から、ユーザーが好む傾向を集計する
/// 純粋関数群。ここで抽出した「お気に入り著者」「よく読むジャンル」を
/// もとに楽天 API に問い合わせて、おすすめ本リストを表示する想定。
library;

import '../models/book.dart';

/// 「高評価」とみなす最低評価しきい値（★4.0 以上）。
const double favoriteRatingThreshold = 4.0;

/// 楽天 API の author 文字列から「主著者名」を取り出す（W9 で追加）。
///
/// 楽天 Books は author を「著者/翻訳者」のように `/` 連結で返してくる
/// （例: "ビル・パーキンス/児島 修"）。そのまま author パラメータに渡すと
/// 検索結果がゼロになるので、最初のセグメントだけ取り出して整形して使う。
///
/// 区切り文字: `/` `／` `、` `,`（楽天は半角 `/` がほとんどだが念のため）。
/// 前後の空白は除去。空文字なら空文字を返す。
String primaryAuthor(String raw) {
  if (raw.isEmpty) return raw;
  final parts = raw.split(RegExp(r'[/／、,]'));
  return parts.first.trim();
}

/// 著者ごとの「お気に入りスコア」を表す集計結果。
class AuthorScore {
  final String author;

  /// その著者の完読本のうち、高評価（★4.0 以上）だった冊数。
  final int favoriteCount;

  /// 完読した冊数（評価に関わらず、参考情報として保持）。
  final int totalFinished;

  /// 高評価本だけの平均評価（0 件のときは 0.0）。
  final double averageFavoriteRating;

  const AuthorScore({
    required this.author,
    required this.favoriteCount,
    required this.totalFinished,
    required this.averageFavoriteRating,
  });
}

/// ユーザーの「お気に入り著者」を集計する。
///
/// 仕様（W9 案 V で改訂）:
///   - 本詳細で `isFavoriteAuthor = true` にされた本の主著者だけを対象に集計
///   - ステータス（読みたい / 読書中 / 読了）は問わない — ユーザーが
///     明示的に「この著者をお気に入り」と宣言した時点で対象
///   - 同じ主著者の本は翻訳者違いでも合算される
///   - 多い順、同点は著者名昇順で安定化
///   - 平均評価は ON にした本のうち rating > 0 の本のみで計算（評価無し
///     を含めると平均が下がるため）
///
/// 統計画面の R7（お気に入り著者 TOP5）とホームタブの「お気に入り著者の
/// 他の作品（R1）」両方から呼ぶ前提。
List<AuthorScore> collectFavoriteAuthors(List<Book> books) {
  final byAuthor = <String, List<Book>>{};
  for (final b in books) {
    if (!b.isFavoriteAuthor) continue;
    final key = primaryAuthor(b.author);
    if (key.isEmpty) continue;
    byAuthor.putIfAbsent(key, () => []).add(b);
  }

  final list = byAuthor.entries.map((e) {
    final favs = e.value;
    final rated = favs.where((b) => b.rating > 0).toList();
    final sum = rated.fold<double>(0, (acc, b) => acc + b.rating);
    return AuthorScore(
      author: e.key,
      favoriteCount: favs.length,
      totalFinished: favs.where((b) => b.status == BookStatus.finished).length,
      averageFavoriteRating: rated.isEmpty ? 0.0 : sum / rated.length,
    );
  }).toList()
    ..sort((a, b) {
      final byCount = b.favoriteCount.compareTo(a.favoriteCount);
      if (byCount != 0) return byCount;
      return a.author.compareTo(b.author);
    });

  return list;
}

/// ユーザーがよく読むジャンル名のリスト（多い順）を抽出する。
///
/// 仕様:
///   - 完読本（status == finished）のうち genre が非 null の本だけ対象
///   - ジャンル名で件数集計
///   - 多い順、同点はジャンル名昇順で安定化
///
/// この結果の上位を楽天 API の booksGenreId 検索に渡しておすすめを取得する。
/// ただし [Book.genre] は名前ベース（"詩・詩集"）で、API には booksGenreId
/// が必要なので、UI 層では同じ本群から genreId も合わせて取り出す。
List<String> collectFavoriteGenres(List<Book> books) {
  final counter = <String, int>{};
  for (final b in books) {
    if (b.status != BookStatus.finished) continue;
    final g = b.genre;
    if (g == null || g.isEmpty) continue;
    counter[g] = (counter[g] ?? 0) + 1;
  }

  final list = counter.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });

  return list.map((e) => e.key).toList();
}

/// 「よく読むジャンル」の booksGenreId バリエーションを集計する。
///
/// 完読本（status == finished）かつ genreId が非 null の本だけ対象。
/// ジャンル ID ごとの件数を多い順に返す（楽天 API のおすすめ取得で使う）。
List<String> collectFavoriteGenreIds(List<Book> books) {
  final counter = <String, int>{};
  for (final b in books) {
    if (b.status != BookStatus.finished) continue;
    final gid = b.genreId;
    if (gid == null || gid.isEmpty) continue;
    counter[gid] = (counter[gid] ?? 0) + 1;
  }

  final list = counter.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });

  return list.map((e) => e.key).toList();
}
