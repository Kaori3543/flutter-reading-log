/// 本に対するレビュー（感想・引用メモ）のデータモデル。
///
/// 1 冊の本に複数のレビューを残せる設計（引用集や感想を分けて記録するため）。
/// W1 でモデル定義、W5 で hive 永続化用の toMap / fromMap と updatedAt を追加。
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

  /// 更新日時（編集された時のみ更新。新規作成時は null）
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.bookId,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  Review copyWith({
    String? id,
    String? bookId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Review(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Review を hive 永続化用の Map に変換する（Book と同じ Map ベース方針）。
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// hive から読み出した Map を Review に変換する。
  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] as String,
      bookId: map['bookId'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
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
