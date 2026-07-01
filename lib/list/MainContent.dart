import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';

/// 本棚のカード「右側」（表紙の右）に表示する本情報。
/// UI 改修: 日付・ボタンを撤去し、タイトルを大きめ・可読性重視に。
/// 「詳細を見る」ボタンは呼び出し側 (BookListItem) が右端に配置する。
class MainContent extends StatelessWidget {
  final Book book;

  const MainContent({
    super.key,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // タイトル: 明朝 + 太字 + 大きめ (titleLarge)。2 行まで。
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: AppColors.fg,
          ),
        ),
        const SizedBox(height: 8),
        // 著者
        Text(
          book.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.mutedFg,
          ),
        ),
        // 出版社 (あれば)
        if ((book.publisher ?? '').isNotEmpty)
          Text(
            book.publisher!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedFg,
            ),
          ),
      ],
    );
  }
}
