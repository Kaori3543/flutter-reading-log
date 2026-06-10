// 楽天 Books API のレスポンスパースのユニットテスト。
//
// `RakutenApi.parseSearchResponse(String)` を直接呼び、モック JSON が
// 期待する List<Book> に変換されることを検証する。
// 通信そのものは外部依存なので W2 ではテスト対象外（W3 以降で
// http.Client のモックを必要に応じて入れる）。

import 'package:flutter_test/flutter_test.dart';
import 'package:sample/models/book.dart';
import 'package:sample/services/rakuten_api.dart';

void main() {
  group('RakutenApi.parseSearchResponse', () {
    test('通常の JSON を List<Book> にパースできる', () {
      const mockJson = '''
{
  "Items": [
    {
      "Item": {
        "title": "ノルウェイの森",
        "author": "村上 春樹",
        "publisherName": "講談社",
        "isbn": "9784062748681",
        "largeImageUrl": "https://example.com/large.jpg",
        "mediumImageUrl": "https://example.com/medium.jpg",
        "smallImageUrl": "https://example.com/small.jpg",
        "itemCaption": "1987年に発表された..."
      }
    },
    {
      "Item": {
        "title": "海辺のカフカ",
        "author": "村上 春樹",
        "publisherName": "新潮社",
        "isbn": "9784101001548",
        "largeImageUrl": "https://example.com/kafka.jpg"
      }
    }
  ]
}
''';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books, hasLength(2));

      expect(books[0].title, 'ノルウェイの森');
      expect(books[0].author, '村上 春樹');
      expect(books[0].publisher, '講談社');
      expect(books[0].isbn, '9784062748681');
      expect(books[0].id, '9784062748681'); // ISBN が id として使われる
      expect(books[0].coverImageUrl, 'https://example.com/large.jpg');
      expect(books[0].status, BookStatus.wantToRead);
      expect(books[0].totalPages, isNull); // 楽天 API には総ページ数情報なし

      expect(books[1].title, '海辺のカフカ');
      expect(books[1].isbn, '9784101001548');
    });

    test('空の Items 配列でも空のリストが返る', () {
      const mockJson = '{"Items": []}';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books, isEmpty);
    });

    test('Items キーが無い場合も空のリストが返る', () {
      const mockJson = '{}';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books, isEmpty);
    });

    test('ISBN が空文字の場合は title を id として使う', () {
      const mockJson = '''
{
  "Items": [
    {
      "Item": {
        "title": "ISBNなしの本",
        "author": "著者",
        "isbn": ""
      }
    }
  ]
}
''';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books, hasLength(1));
      expect(books[0].id, 'ISBNなしの本');
      expect(books[0].isbn, isNull);
    });

    test('画像 URL の優先順: large → medium → small', () {
      const mockJson = '''
{
  "Items": [
    {
      "Item": {
        "title": "Large のみ",
        "author": "A",
        "largeImageUrl": "L",
        "isbn": "1"
      }
    },
    {
      "Item": {
        "title": "Medium まで",
        "author": "B",
        "largeImageUrl": "",
        "mediumImageUrl": "M",
        "isbn": "2"
      }
    },
    {
      "Item": {
        "title": "Small だけ",
        "author": "C",
        "largeImageUrl": "",
        "mediumImageUrl": "",
        "smallImageUrl": "S",
        "isbn": "3"
      }
    },
    {
      "Item": {
        "title": "画像なし",
        "author": "D",
        "isbn": "4"
      }
    }
  ]
}
''';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books[0].coverImageUrl, 'L');
      expect(books[1].coverImageUrl, 'M');
      expect(books[2].coverImageUrl, 'S');
      expect(books[3].coverImageUrl, isNull);
    });

    test('booksGenreId を Book.genreId にセットする、genre は未取得（W7）', () {
      // 検索 API は booksGenreId（例: "001004009"）しか返さない。
      // 人間可読な genre 名は本登録時に BooksGenre/Search API で取得する設計。
      // ここではパース段階で id だけ保持できることを確認。
      const mockJson = '''
{
  "Items": [
    {
      "Item": {
        "title": "詩集",
        "author": "A",
        "isbn": "1",
        "booksGenreId": "001004009"
      }
    },
    {
      "Item": {
        "title": "ジャンルなし",
        "author": "B",
        "isbn": "2"
      }
    },
    {
      "Item": {
        "title": "空文字",
        "author": "C",
        "isbn": "3",
        "booksGenreId": ""
      }
    }
  ]
}
''';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(books[0].genreId, '001004009');
      expect(books[0].genre, isNull); // 名前は別途取得
      expect(books[1].genreId, isNull);
      expect(books[1].genre, isNull);
      expect(books[2].genreId, isNull);
    });

    test('parseGenreNameResponse は current.booksGenreName を返す（W7）', () {
      // BooksGenre/Search API のレスポンス形式:
      //   { "parents": [...], "current": {"booksGenreId": "...", "booksGenreName": "..."}, "children": [...] }
      const mockJson = '''
{
  "parents": [
    {"parent": {"booksGenreId": "001", "booksGenreName": "本"}},
    {"parent": {"booksGenreId": "001004", "booksGenreName": "小説・エッセイ"}}
  ],
  "current": {
    "booksGenreId": "001004009",
    "booksGenreName": "詩・詩集"
  },
  "children": []
}
''';

      final name = RakutenApi.parseGenreNameResponse(mockJson);
      expect(name, '詩・詩集');
    });

    test('parseGenreNameResponse は current が無い場合 null を返す', () {
      const mockJson = '{"parents": [], "children": []}';
      final name = RakutenApi.parseGenreNameResponse(mockJson);
      expect(name, isNull);
    });

    test('parseGenreNameResponse は booksGenreName が空文字の場合 null を返す', () {
      const mockJson =
          '{"current": {"booksGenreId": "x", "booksGenreName": ""}}';
      final name = RakutenApi.parseGenreNameResponse(mockJson);
      expect(name, isNull);
    });

    test('検索結果の本のステータスは全て wantToRead', () {
      const mockJson = '''
{
  "Items": [
    {"Item": {"title": "A", "author": "X", "isbn": "1"}},
    {"Item": {"title": "B", "author": "Y", "isbn": "2"}}
  ]
}
''';

      final books = RakutenApi.parseSearchResponse(mockJson);

      expect(
        books.every((b) => b.status == BookStatus.wantToRead),
        isTrue,
      );
    });
  });

  group('RakutenApiException', () {
    test('toString が message を含む', () {
      final e = RakutenApiException('テスト用エラー');
      expect(e.toString(), contains('テスト用エラー'));
    });
  });
}
