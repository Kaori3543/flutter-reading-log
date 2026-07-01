/// ランキング/検索結果の本を「本棚に追加するか」決めるための BottomSheet（W8）。
///
/// 発見タブのランキングカードをタップした時に表示する。
/// 表紙・タイトル・著者・出版社・あらすじを一覧し、「本棚に追加」
/// ボタンで hive 保存 + ジャンル名解決まで行う。
///
/// UI: AppColors パレット統一。タイトルは Noto Serif JP、あらすじ見出しは
/// uppercase-tracking スタイル、追加ボタンは primary pill。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../services/rakuten_api.dart';
import '../theme/app_theme.dart';

/// BottomSheet を開くヘルパー。
///
/// 呼び出し側からは `showBookDetailSheet(context, ref: ref, book: book, api: api,
/// caption: caption)` の形で呼ぶ。caption は楽天 API レスポンスから事前に
/// 取り出した「あらすじ」テキスト（Book モデルには載らないので呼び出し側で
/// 抽出して渡す）。
Future<void> showBookDetailSheet(
  BuildContext context, {
  required WidgetRef ref,
  required Book book,
  required RakutenApi api,
  String? caption,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _BookDetailSheetContent(
      book: book,
      api: api,
      caption: caption,
    ),
  );
}

class _BookDetailSheetContent extends ConsumerStatefulWidget {
  final Book book;
  final RakutenApi api;
  final String? caption;

  const _BookDetailSheetContent({
    required this.book,
    required this.api,
    required this.caption,
  });

  @override
  ConsumerState<_BookDetailSheetContent> createState() =>
      _BookDetailSheetContentState();
}

class _BookDetailSheetContentState
    extends ConsumerState<_BookDetailSheetContent> {
  bool _isAdding = false;

  Future<void> _addToBookshelf() async {
    final notifier = ref.read(bookListProvider.notifier);
    if (notifier.exists(widget.book.id)) {
      // 表示中に他経路で追加された場合のフォールバック
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${widget.book.title}」は既に本棚にあります')),
      );
      return;
    }

    setState(() => _isAdding = true);

    // W9: 本棚追加日時を記録（積読放置リマインダー R5 で使う）。
    Book toSave = widget.book.copyWith(addedAt: DateTime.now());

    // ジャンル名取得（失敗時は genre = null のまま登録、本登録自体は止めない）
    final gid = toSave.genreId;
    if (gid != null && gid.isNotEmpty) {
      try {
        final name = await widget.api.getGenreName(gid);
        if (name != null) toSave = toSave.copyWith(genre: name);
      } catch (_) {
        // 黙殺
      }
    }
    await notifier.add(toSave);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「${toSave.title}」を本棚に追加しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 既に登録済みかは provider を watch して反映（他経路で消えた・追加された
    // 場合でも sheet 内の表示が更新される）。
    final books = ref.watch(bookListProvider);
    final alreadyExists = books.any((b) => b.id == widget.book.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // カバー: 影付きで中央に配置。
              Center(child: _cover()),
              const SizedBox(height: 20),
              // タイトル (明朝)。
              Text(
                widget.book.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              // 著者 (出版社)。
              Text(
                widget.book.author +
                    (widget.book.publisher != null
                        ? '（${widget.book.publisher}）'
                        : ''),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.mutedFg),
              ),
              const SizedBox(height: 24),
              if (widget.caption != null && widget.caption!.isNotEmpty) ...[
                // あらすじ見出し (uppercase-tracking の muted)。
                const Text(
                  'あらすじ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.2,
                    color: AppColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.caption!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.fg.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // 本棚に追加 / 登録済み ボタン (pill primary)。
              SizedBox(
                width: double.infinity,
                child: alreadyExists
                    ? FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('本棚に登録済み'),
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: AppColors.secondary,
                          disabledForegroundColor: AppColors.mutedFg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _isAdding ? null : _addToBookshelf,
                        icon: _isAdding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryFg,
                                ),
                              )
                            : const Icon(Icons.add, size: 18),
                        label: Text(_isAdding ? '追加中...' : '本棚に追加'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryFg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// カバー画像。本棚と同じ立体感 (影付き) で表示。
  Widget _cover() {
    final url = widget.book.coverImageUrl;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = Container(
        width: 130,
        height: 185,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book_outlined, size: 60, color: Colors.black54),
        ),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        height: 185,
        fit: BoxFit.contain,
        placeholder: (c, _) => const SizedBox(
          height: 185,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (c, _, __) => Container(
          width: 130,
          height: 185,
          color: Colors.grey.shade200,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: image,
    );
  }
}
