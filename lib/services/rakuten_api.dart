/// 楽天 Books API client。
///
/// W2 で導入。書名から本を検索し、Book リストを返す。
///
/// 2024 年以降、楽天 Developers の API 仕様が変更されたことを反映:
/// - エンドポイントが app.rakuten.co.jp → openapi.rakuten.co.jp に変更
/// - applicationId が数値文字列 → UUID 文字列に
/// - accessKey が【NEW】必須パラメータとして追加
///
/// applicationId と accessKey は --dart-define で渡す前提:
///   --dart-define=RAKUTEN_APP_ID=xxx
///   --dart-define=RAKUTEN_ACCESS_KEY=xxx
/// .vscode/launch.json でこれらを設定してあれば VS Code 起動時に自動で
/// 渡される（launch.example.json をテンプレートとして参照）。
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:sample/models/book.dart';

/// 楽天 Books API のエンドポイント（書籍検索 v20170404）。
/// 仕様: https://webservice.rakuten.co.jp/documentation/books-book-search
const _baseUrl =
    'https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404';

/// Cloudflare Worker で立てた CORS 対応プロキシ。Web ビルド (kIsWeb=true) の
/// ときだけ経由する。ネイティブ (Windows/Android/iOS) からは直接 [_baseUrl] /
/// [_genreUrl] を叩けるので Worker は使わない。
///
/// Worker のエンドポイント:
///   /books/search → BooksBook/Search
///   /books/genre  → BooksGenre/Search
///
/// applicationId / accessKey は Worker 側 secret に入れてあるので、クライアン
/// トから渡す必要はない (URL に付けても Worker が削除して自前のを付ける)。
const _proxyBaseUrl =
    'https://reading-log-rakuten-proxy.tamable-attendance.workers.dev';

/// 書籍検索 API の実際に叩くエンドポイントを返す。
String _searchEndpoint() => kIsWeb ? '$_proxyBaseUrl/books/search' : _baseUrl;

/// ジャンル検索 API の実際に叩くエンドポイントを返す。
String _genreEndpoint() => kIsWeb ? '$_proxyBaseUrl/books/genre' : _genreUrl;

/// BooksGenre/Search レスポンスから取り出すジャンル情報（W9）。
///
/// `getGenreName` が複数 ID から「最も深い階層」のジャンル名を選ぶために
/// 階層レベル（`genreLevel`）を一緒に持ち回る。
class _GenreInfo {
  final String name;
  final int level;
  const _GenreInfo({required this.name, required this.level});
}

/// 発見タブのランキング表示で使う、本 + あらすじの組（W8）。
///
/// 楽天 API のレスポンスから抽出した `itemCaption`（あらすじテキスト）は
/// 本棚に保存する [Book] モデルには含めず、BottomSheet の表示にだけ使う。
/// なので Book と別に持ち回るためのレコード型として定義する。
typedef RankingItem = ({Book book, String? caption});

/// 楽天 Books ジャンル検索 API のエンドポイント（v20121128）。
/// W7 で追加。booksGenreId → 人間可読なジャンル名の変換に使う。
/// 仕様: https://webservice.rakuten.co.jp/documentation/books-genre-search
const _genreUrl =
    'https://openapi.rakuten.co.jp/services/api/BooksGenre/Search/20121128';

/// 楽天 API 呼び出し時のエラー。
///
/// 通信エラー・サーバエラー・applicationId/accessKey 未設定など、API 呼び出し全般の
/// 失敗を表す。FutureBuilder の `snapshot.error` 経由で UI に表示される。
class RakutenApiException implements Exception {
  final String message;
  RakutenApiException(this.message);
  @override
  String toString() => 'RakutenApiException: $message';
}

/// 楽天 Books API クライアント。
///
/// テスタビリティのため `http.Client`, `applicationId`, `accessKey` を
/// constructor で注入できるようにしている。本番では引数省略で
/// --dart-define 由来の値と新規 http.Client が使われる。
class RakutenApi {
  final http.Client _client;
  final String _applicationId;
  final String _accessKey;

  /// 一度取得した booksGenreId → ジャンル名のキャッシュ（W7）。
  ///
  /// 楽天 API はレート制限（1 リクエスト/秒）があるため、同じ ID に対して
  /// 何度も BooksGenre/Search を叩かないようにメモリに保持する。
  /// インスタンスのライフサイクル内のみ有効（アプリ再起動でクリア）。
  final Map<String, String> _genreNameCache = {};

  /// ランキング検索結果のキャッシュ（W8）。
  ///
  /// キーは `"{booksGenreId}/{hits}"` 形式。発見タブを開くたびに同じ API を
  /// 叩かないようにする。インスタンスのライフサイクル内のみ有効。
  final Map<String, List<RankingItem>> _rankingCache = {};

  RakutenApi({
    http.Client? client,
    String? applicationId,
    String? accessKey,
  })  : _client = client ?? http.Client(),
        _applicationId =
            applicationId ?? const String.fromEnvironment('RAKUTEN_APP_ID'),
        _accessKey =
            accessKey ?? const String.fromEnvironment('RAKUTEN_ACCESS_KEY');

  /// booksGenreId（例 "001004009"）からジャンル名を取得する（W7）。
  ///
  /// 楽天 BooksGenre/Search API を叩いて `current.booksGenreName` を返す。
  /// 同じ id は 2 回目以降キャッシュから返す。
  /// applicationId / accessKey 未設定時や通信失敗時は null を返す（呼び出し側で
  /// genre = null として登録できるよう、本登録フローを止めない設計）。
  Future<String?> getGenreName(String booksGenreId) async {
    if (booksGenreId.isEmpty) return null;

    // キャッシュキーは raw 全体（複数 ID 文字列も含めて 1 度の検索でキャッシュ）。
    final cached = _genreNameCache[booksGenreId];
    if (cached != null) return cached;

    if (_applicationId.isEmpty || _accessKey.isEmpty) return null;

    // 楽天の booksGenreId は `/` 区切りで複数ジャンルが入る場合がある
    // （例: "001008027/001006018002"）。各 ID で API を叩き、その中で
    // 最も `genreLevel` の大きい（最も具体的な）名前を採用する。
    // 「その他」など上位カテゴリの汎用名を避けて、ユーザーに意味のある
    // ジャンル名を見せるための工夫。
    final ids = booksGenreId
        .split('/')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.isEmpty) return null;

    String? bestName;
    int bestLevel = -1;
    for (final id in ids) {
      // 個別 ID もキャッシュ（同じ ID が別の本でも出てくる前提）
      final perIdCached = _genreNameCache['_single:$id'];
      _GenreInfo? info;
      if (perIdCached != null) {
        info = _GenreInfo(name: perIdCached, level: -1);
      } else {
        try {
          final uri = Uri.parse(_genreEndpoint()).replace(queryParameters: {
            'applicationId': _applicationId,
            'accessKey': _accessKey,
            'booksGenreId': id,
            'format': 'json',
          });
          final response = await _client.get(uri);
          if (response.statusCode != 200) continue;
          info = _parseGenreInfo(response.body);
          if (info != null) _genreNameCache['_single:$id'] = info.name;
        } catch (_) {
          continue;
        }
      }
      if (info == null) continue;
      // 個別キャッシュは level を持たないので、その場合は最後の API レスポンスの
      // level を信用しきれないが、未取得 ID が混じったケースの fallback として
      // 機能する（level=-1 はまだ何も決まってない場合のみ採用）。
      if (info.level > bestLevel) {
        bestName = info.name;
        bestLevel = info.level;
      }
    }

    if (bestName != null) {
      _genreNameCache[booksGenreId] = bestName;
    }
    return bestName;
  }

  /// BooksGenre/Search のレスポンス JSON から `current.booksGenreName` を抽出する。
  /// テスト互換のため public + static（W9 で内部実装は _parseGenreInfo に委譲）。
  static String? parseGenreNameResponse(String body) {
    return _parseGenreInfo(body)?.name;
  }

  /// BooksGenre/Search のレスポンスから `(name, level)` を取り出す（W9）。
  /// 複数 ID 解決時に最も深い階層の名前を選ぶために level も必要。
  static _GenreInfo? _parseGenreInfo(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    final name = current['booksGenreName'] as String?;
    if (name == null || name.isEmpty) return null;
    final level = (current['genreLevel'] as num?)?.toInt() ?? 0;
    return _GenreInfo(name: name, level: level);
  }

  /// 楽天 Books API でタイトル検索する。
  ///
  /// 戻り値は最大 30 件の Book リスト（楽天 API のデフォルト hits=30）。
  /// 著者検索やキーワード検索が必要になったら別メソッドを追加するか、
  /// このメソッドに引数を増やして拡張する想定。
  Future<List<Book>> searchBooks(String query) async {
    if (_applicationId.isEmpty) {
      throw RakutenApiException(
        'RAKUTEN_APP_ID が設定されていません。'
        '.vscode/launch.json の --dart-define=RAKUTEN_APP_ID=xxx を確認してください。',
      );
    }
    if (_accessKey.isEmpty) {
      throw RakutenApiException(
        'RAKUTEN_ACCESS_KEY が設定されていません。'
        '.vscode/launch.json の --dart-define=RAKUTEN_ACCESS_KEY=xxx を確認してください。'
        '（楽天 Developers の「アクセスキー」欄から値を取得してください）',
      );
    }

    final uri = Uri.parse(_searchEndpoint()).replace(queryParameters: {
      'applicationId': _applicationId,
      'accessKey': _accessKey,
      // 楽天 Books API は title / author / publisherName / isbn / size /
      // booksGenreId のいずれか 1 つを必須とする。title が一番直感的なので
      // これを採用。著者検索を入れたい場合は SearchPage 側でモード切り替え。
      'title': query,
      'format': 'json',
      'hits': '30',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw RakutenApiException(
        '楽天 API リクエスト失敗 (status: ${response.statusCode})',
      );
    }

    return parseSearchResponse(response.body);
  }

  /// 指定ジャンルの売れている順ランキングを取得する（W8）。
  ///
  /// 楽天 Books の Search API に `booksGenreId` + `sort=sales` を指定すると、
  /// そのジャンルで売れている順に並んだ本リストが返る。レスポンスの配列順
  /// がそのままランキング順位（先頭 = 1 位）。
  ///
  /// 戻り値の本は genreId が必ずセットされる（呼び出し元のセクションが
  /// どのジャンルだったか分かるように）。本登録時のジャンル名解決は
  /// 既存 [getGenreName] と同じ流れで行う。
  ///
  /// レスポンスはメモリにキャッシュする（同 (genreId, hits) はセッション内で
  /// 2 回目以降 API を叩かない）。
  Future<List<RankingItem>> searchRanking({
    required String booksGenreId,
    int hits = 20,
  }) async {
    if (_applicationId.isEmpty || _accessKey.isEmpty) {
      // 検索 API と違い、ランキングは「画面の一部」なので例外ではなく空配列
      // を返す（ローディング失敗を呼び出し側でハンドリングしやすい）。
      return const [];
    }

    final cacheKey = '$booksGenreId/$hits';
    final cached = _rankingCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse(_searchEndpoint()).replace(queryParameters: {
      'applicationId': _applicationId,
      'accessKey': _accessKey,
      'booksGenreId': booksGenreId,
      'sort': 'sales',
      'format': 'json',
      'hits': '$hits',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return const [];
      final items = parseRankingResponse(response.body);
      _rankingCache[cacheKey] = items;
      return items;
    } catch (_) {
      return const [];
    }
  }

  /// 著者名で楽天 Books を検索し、ランキング形式（RankingItem）で返す（W9）。
  ///
  /// 「あなたへのおすすめ」でお気に入り著者の他作品を提示するために使う。
  /// 楽天 API は author パラメータをサポートしているのでそのまま渡す。
  /// 売れている順（sort=sales）で取得し、ランキングカードと同じ UI を使い回す。
  ///
  /// メモリキャッシュは searchRanking と同じ _rankingCache を共用
  /// （キーに `"author:{name}"` プレフィックスを付けて booksGenreId と衝突回避）。
  Future<List<RankingItem>> searchByAuthor({
    required String author,
    int hits = 20,
  }) async {
    if (_applicationId.isEmpty || _accessKey.isEmpty) return const [];
    if (author.isEmpty) return const [];

    // W9: 楽天 Books の author は「著者/翻訳者」連結で返ってくるため、
    // 主著者だけを残してから検索する。すでに整形済みの文字列が渡ってきた
    // 場合は無加工で通過する（区切り文字を含まなければそのまま）。
    final normalized = author.split(RegExp(r'[/／、,]')).first.trim();
    if (normalized.isEmpty) return const [];

    final cacheKey = 'author:$normalized/$hits';
    final cached = _rankingCache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse(_searchEndpoint()).replace(queryParameters: {
      'applicationId': _applicationId,
      'accessKey': _accessKey,
      'author': normalized,
      'sort': 'sales',
      'format': 'json',
      'hits': '$hits',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return const [];
      final items = parseRankingResponse(response.body);
      _rankingCache[cacheKey] = items;
      return items;
    } catch (_) {
      return const [];
    }
  }

  /// 楽天 API の検索レスポンスを `(Book, あらすじ)` のリストに変換する（W8）。
  ///
  /// 構造は [parseSearchResponse] と同じだが、ランキング/発見タブ用に
  /// itemCaption（あらすじテキスト）も一緒に取り出す。Book モデルには
  /// 保存しない transient なデータ。
  static List<RankingItem> parseRankingResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['Items'] as List<dynamic>? ?? [];

    return items.map<RankingItem>((wrapped) {
      final item = (wrapped as Map<String, dynamic>)['Item']
          as Map<String, dynamic>;
      final book = _buildBookFromItem(item);
      final caption = item['itemCaption'] as String?;
      return (
        book: book,
        caption: (caption != null && caption.isNotEmpty) ? caption : null,
      );
    }).toList();
  }

  /// 楽天 API の検索レスポンス JSON を `List<Book>` にパースする。
  ///
  /// テスト容易性のため public + static にした（モック JSON を渡してパース
  /// ロジック単体を検証できる）。
  static List<Book> parseSearchResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final items = json['Items'] as List<dynamic>? ?? [];

    return items.map((wrapped) {
      final item = (wrapped as Map<String, dynamic>)['Item']
          as Map<String, dynamic>;
      return _buildBookFromItem(item);
    }).toList();
  }

  /// 楽天 API の `Item` オブジェクトから [Book] を組み立てる共通ロジック。
  ///
  /// [parseSearchResponse] と [parseRankingResponse] の重複を排除するため、
  /// W8 で切り出した。Book モデルにそのまま入る項目だけを扱う
  /// （あらすじ itemCaption は呼び出し側で別途取り出す）。
  static Book _buildBookFromItem(Map<String, dynamic> item) {
    final isbn = item['isbn'] as String? ?? '';
    final title = item['title'] as String? ?? '(タイトル不明)';

    return Book(
      // ISBN があれば id として使用、なければ title を fallback として使う
      // （W3 で hive に保存する際の一意キー）。
      id: isbn.isNotEmpty ? isbn : title,
      isbn: isbn.isNotEmpty ? isbn : null,
      title: title,
      author: item['author'] as String? ?? '(著者不明)',
      publisher: item['publisherName'] as String?,
      // 画像は large → medium → small の優先順で使う。
      coverImageUrl: (item['largeImageUrl'] as String?)?.isNotEmpty == true
          ? item['largeImageUrl'] as String
          : (item['mediumImageUrl'] as String?)?.isNotEmpty == true
              ? item['mediumImageUrl'] as String
              : item['smallImageUrl'] as String?,
      // 楽天 Books API のレスポンスには総ページ数が含まれないため null。
      totalPages: null,
      // 検索結果は「読みたい候補」なので wantToRead を初期値に。
      // 実際に本棚に登録する時はユーザーがステータスを選び直す（W3）。
      status: BookStatus.wantToRead,
      // W7: 検索結果には booksGenreId（例: "001004009"）だけが入る。
      // 人間可読なジャンル名は本登録時に getGenreName で別途取得して
      // Book.genre にセットする（ここでは genre は null のまま）。
      genreId: (item['booksGenreId'] as String?)?.isNotEmpty == true
          ? item['booksGenreId'] as String
          : null,
    );
  }
}
