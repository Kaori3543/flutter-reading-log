/// 本に対するレビュー（感想・引用メモ）のデータモデル。
///
/// 1 冊の本に複数のレビューを残せる設計（引用集や感想を分けて記録するため）。
/// W1 ではモデル定義のみで CRUD は W5 で実装予定。
library;

class Review {
  /// レビュー自身の一意な ID
  final String id;

  /// レビュー対象の Book.id（外部キー的役割）
  final String bookId;

  /// レビュー本文（感想・引用テキストなど）
  final String content;

  /// 作成日時
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.bookId,
    required this.content,
    required this.createdAt,
  });

  Review copyWith({
    String? id,
    String? bookId,
    String? content,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Review && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Review(id: $id, bookId: $bookId, createdAt: $createdAt)';
}
