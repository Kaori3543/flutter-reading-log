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
import 'package:http/http.dart' as http;
import 'package:sample/models/book.dart';

/// 楽天 Books API のエンドポイント（書籍検索 v20170404）。
/// 仕様: https://webservice.rakuten.co.jp/documentation/books-book-search
const _baseUrl =
    'https://openapi.rakuten.co.jp/services/api/BooksBook/Search/20170404';

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

    // キャッシュヒット → 即返却
    final cached = _genreNameCache[booksGenreId];
    if (cached != null) return cached;

    if (_applicationId.isEmpty || _accessKey.isEmpty) return null;

    final uri = Uri.parse(_genreUrl).replace(queryParameters: {
      'applicationId': _applicationId,
      'accessKey': _accessKey,
      'booksGenreId': booksGenreId,
      'format': 'json',
    });

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) return null;
      final name = parseGenreNameResponse(response.body);
      if (name != null) {
        _genreNameCache[booksGenreId] = name;
      }
      return name;
    } catch (_) {
      // 通信エラー・パース失敗は null として扱う（本登録は続行可能）
      return null;
    }
  }

  /// BooksGenre/Search のレスポンス JSON から `current.booksGenreName` を抽出する。
  /// テスト容易性のため public + static にした。
  static String? parseGenreNameResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;
    final name = current['booksGenreName'] as String?;
    if (name == null || name.isEmpty) return null;
    return name;
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

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
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
      final isbn = item['isbn'] as String? ?? '';
      final title = item['title'] as String? ?? '(タイトル不明)';

      return Book(
        // ISBN があれば id として使用、なければ title を fallback として
        // 使う（W3 で hive に保存する際の一意キー）。
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
    }).toList();
  }
}
