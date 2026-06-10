/// 読書記録アプリの中核となる「本」のデータモデル。
///
/// W1 ではダミーデータを保持するためのプレーンな Dart クラスとして実装。
/// W3 で hive 永続化のための toMap / fromMap を追加（Map ベース、codegen 不要）。
library;

/// 本の読書ステータス。
enum BookStatus {
  /// 読みたい（積読）
  wantToRead,

  /// 読書中
  reading,

  /// 読了
  finished,
}

class Book {
  /// アプリ内での一意な ID（W3 で hive キーになる予定）
  final String id;

  /// ISBN コード（楽天 API 経由で取得予定、W1 では null 可）
  final String? isbn;

  /// 書名
  final String title;

  /// 著者名
  final String author;

  /// 出版社
  final String? publisher;

  /// 表紙画像 URL（W3 で楽天 API 由来の URL に置換）
  final String? coverImageUrl;

  /// 総ページ数
  final int? totalPages;

  /// 読書ステータス
  final BookStatus status;

  /// 現在のページ（読書中の進捗）
  final int currentPage;

  /// 評価（0.0〜5.0）
  final double rating;

  /// 読み始めた日
  final DateTime? startedAt;

  /// 読了した日
  final DateTime? finishedAt;

  /// ジャンル名（W7 で追加）。
  ///
  /// 表示・統計集計で使う人間可読なジャンル名（例: "詩・詩集"）。
  /// 楽天 Books API は本検索のレスポンスでジャンル ID（[genreId]）しか
  /// 返さないため、本登録時に BooksGenre/Search API で ID → 名前変換した
  /// 結果を保存する。
  /// W7 以前に登録された本や ID 解決に失敗した本は null。
  /// null の本は統計のジャンル別集計から除外。
  final String? genre;

  /// 楽天 Books API のジャンル ID（W7 で追加）。
  ///
  /// 例: "001004009"。階層化された数字文字列。
  /// 検索結果からの本にはこの ID が入っており、本登録時に
  /// [RakutenApi.getGenreName] で名前を引いて [genre] にセットする。
  /// W7 以前に登録された本は null。
  final String? genreId;

  const Book({
    required this.id,
    this.isbn,
    required this.title,
    required this.author,
    this.publisher,
    this.coverImageUrl,
    this.totalPages,
    this.status = BookStatus.wantToRead,
    this.currentPage = 0,
    this.rating = 0.0,
    this.startedAt,
    this.finishedAt,
    this.genre,
    this.genreId,
  });

  /// 一部のフィールドだけ更新した新しい Book を返す。
  /// Riverpod の StateNotifier で不変オブジェクトを更新する際に使用。
  Book copyWith({
    String? id,
    String? isbn,
    String? title,
    String? author,
    String? publisher,
    String? coverImageUrl,
    int? totalPages,
    BookStatus? status,
    int? currentPage,
    double? rating,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? genre,
    String? genreId,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      title: title ?? this.title,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      totalPages: totalPages ?? this.totalPages,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      rating: rating ?? this.rating,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      genre: genre ?? this.genre,
      genreId: genreId ?? this.genreId,
    );
  }

  /// Book を hive 永続化用の Map に変換する。
  ///
  /// hive_ce は Map をネイティブで保存できるため、codegen (TypeAdapter) を
  /// 使わずに済む（W3 で確定した方針）。
  /// enum は name 文字列、DateTime は ISO8601 文字列にして安全に保存する。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'publisher': publisher,
      'coverImageUrl': coverImageUrl,
      'totalPages': totalPages,
      'status': status.name,
      'currentPage': currentPage,
      'rating': rating,
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'genre': genre,
      'genreId': genreId,
    };
  }

  /// hive から読み出した Map を Book に変換する。
  ///
  /// 旧データのフィールド欠落や型不一致に耐性を持たせるため、必須項目
  /// 以外は null 安全に扱う（status は値が壊れていたら wantToRead に
  /// fallback）。
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      isbn: map['isbn'] as String?,
      title: map['title'] as String,
      author: map['author'] as String,
      publisher: map['publisher'] as String?,
      coverImageUrl: map['coverImageUrl'] as String?,
      totalPages: map['totalPages'] as int?,
      status: BookStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => BookStatus.wantToRead,
      ),
      currentPage: map['currentPage'] as int? ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      startedAt: map['startedAt'] != null
          ? DateTime.parse(map['startedAt'] as String)
          : null,
      finishedAt: map['finishedAt'] != null
          ? DateTime.parse(map['finishedAt'] as String)
          : null,
      genre: map['genre'] as String?,
      genreId: map['genreId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Book(id: $id, title: $title, status: $status)';
}
