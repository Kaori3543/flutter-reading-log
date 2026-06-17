/// ランキング/検索結果の本を「本棚に追加するか」決めるための BottomSheet（W8）。
///
/// 発見タブのランキングカードをタップした時に表示する。
/// 表紙・タイトル・著者・出版社・あらすじ・出版日を一覧し、「本棚に追加」
/// ボタンで hive 保存 + ジャンル名解決まで行う。
///
/// 設計メモ:
///   - 楽天 API の itemCaption（あらすじ）は 100 〜 数百文字あるので、最大 8 行
///     程度に制限してその先はスクロール
///   - 既に本棚に登録済みの本は「登録済み」のラベルに変えて、再追加できない
///     ようにする
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../services/rakuten_api.dart';

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

    // ジャンル名取得（失敗時は genre = null のまま登録、本登録自体は止めない）
    Book toSave = widget.book;
    final gid = widget.book.genreId;
    if (gid != null && gid.isNotEmpty) {
      try {
        final name = await widget.api.getGenreName(gid);
        if (name != null) toSave = widget.book.copyWith(genre: name);
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
    // 既に登録済みかは provider を watch して反映（他経路で消えた・追加された
    // 場合でも sheet 内の表示が更新される）。
    final books = ref.watch(bookListProvider);
    final alreadyExists = books.any((b) => b.id == widget.book.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _cover()),
              const SizedBox(height: 16),
              Text(
                widget.book.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.book.author +
                    (widget.book.publisher != null
                        ? '（${widget.book.publisher}）'
                        : ''),
                style:
                    const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              if (widget.caption != null && widget.caption!.isNotEmpty) ...[
                const Text(
                  'あらすじ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.caption!,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: alreadyExists
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check),
                        label: const Text('本棚に登録済み'),
                      )
                    : ElevatedButton.icon(
                        onPressed: _isAdding ? null : _addToBookshelf,
                        icon: _isAdding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add),
                        label: Text(_isAdding ? '追加中...' : '本棚に追加'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cover() {
    final url = widget.book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 120,
        height: 170,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book, size: 60, color: Colors.black54),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: 170,
      fit: BoxFit.contain,
      placeholder: (c, _) => const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (c, _, __) => Container(
        width: 120,
        height: 170,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}
