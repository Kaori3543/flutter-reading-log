import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';

/// 本棚のグリッド 1 マス（縦型カード）。
///
/// - 上段: ダーク茶グラデーション帯にカバー画像を 3D perspective + 影で配置。
///   右上にステータスバッジ、左上にお気に入り♥（該当時のみ）。
/// - 下段: 白背景、タイトル (明朝) + 著者 + 出版社 + ★行 + 詳細ボタン。
class BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback onPressed;

  /// ボタン文言。本棚では「詳細を見る」、検索結果では「本棚に追加」など。
  final String actionLabel;

  /// ステータスバッジを表示するか。検索結果 (本棚未登録) では false 推奨。
  final bool showStatusBadge;

  /// ★評価を表示するか。検索結果 (未評価) では false 推奨。
  final bool showRating;

  /// 「詳細を見る」ボタンを表示するか。ホームの縦カードでは false 推奨。
  final bool showActionButton;

  /// コンパクトモード: 表紙帯・カバー・フォント・余白を一段小さくする。
  /// ホームの横スクロール用途で使う想定。
  final bool compact;

  const BookListItem({
    super.key,
    required this.book,
    required this.onPressed,
    this.actionLabel = '詳細',
    this.showStatusBadge = true,
    this.showRating = true,
    this.showActionButton = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 上段: カバー
            _coverBand(),
            // 下段: 情報
            Expanded(child: _infoArea(context)),
          ],
        ),
      ),
    );
  }

  Widget _coverBand() {
    return Container(
      height: compact ? 140 : 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.asideStart, AppColors.asideEnd],
        ),
      ),
      child: Stack(
        children: [
          Center(child: _coverTilted()),
          if (showStatusBadge)
            Positioned(top: 10, right: 10, child: _statusBadge()),
          if (book.isFavorite)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    size: 12, color: Color(0xFFE05252)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coverTilted() {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateY(-0.07),
      child: Container(
        width: compact ? 84 : 90,
        height: compact ? 120 : 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Hero(tag: 'cover-${book.id}', child: _imageWidget()),
        ),
      ),
    );
  }

  /// ステータスバッジ (色は Figma と揃える)。
  Widget _statusBadge() {
    final (label, bg, fg) = _statusStyle();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }

  (String, Color, Color) _statusStyle() {
    switch (book.status) {
      case BookStatus.wantToRead:
        return ('読みたい', const Color(0xFFE8DFD4), const Color(0xFF7A5A42));
      case BookStatus.reading:
        return ('読書中', const Color(0xFFDDEAF5), const Color(0xFF3A6A9A));
      case BookStatus.finished:
        return ('読了', const Color(0xFFD8F0E4), const Color(0xFF2E7A52));
    }
  }

  Widget _infoArea(BuildContext context) {
    final theme = Theme.of(context);
    final pad = compact
        ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
        : const EdgeInsets.fromLTRB(14, 14, 14, 12);
    // タイトルフォントは本棚と統一 (Noto Serif JP / titleSmall / w600)。
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.fg,
      height: compact ? 1.25 : 1.3,
    );
    final subStyle = TextStyle(
      fontSize: compact ? 11 : 12,
      color: AppColors.mutedFg,
    );
    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: subStyle,
          ),
          if ((book.publisher ?? '').isNotEmpty && !compact)
            Text(
              book.publisher!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subStyle,
            ),
          const Spacer(),
          if (showRating || showActionButton)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showRating) _stars(),
                const Spacer(),
                if (showActionButton)
                  FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryFg,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _stars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = book.rating >= i + 1;
        return Padding(
          padding: const EdgeInsets.only(right: 1.5),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            size: 13,
            color: filled ? AppColors.accent : AppColors.starIdle,
          ),
        );
      }),
    );
  }

  /// カバー画像（キャッシュ + Hero）。
  Widget _imageWidget() {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book_outlined, size: 32, color: Colors.black54),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade100,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}
