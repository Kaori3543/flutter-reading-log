/// 読書記録アプリの中核となる「本」のデータモデル。
///
/// W1 ではダミーデータを保持するためのプレーンな Dart クラスとして実装。
/// W3 で hive にシリアライズするときに toJson/fromJson を追加予定。
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
