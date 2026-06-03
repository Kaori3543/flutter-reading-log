/// レビューの新規作成 / 編集ページ。
///
/// W5 で追加。AppBar の右側に「保存（チェック）」+ 編集モードでは
/// 「削除（ゴミ箱）」を配置。本文は複数行 TextField で入力。
///
/// 呼び出し方:
///   - 新規: ReviewEditPage(bookId: book.id)
///   - 編集: ReviewEditPage(bookId: book.id, existingReview: review)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sample/models/review.dart';
import 'package:sample/providers/review_list_provider.dart';

class ReviewEditPage extends ConsumerStatefulWidget {
  final String bookId;

  /// 編集モード: null でない時は既存レビューの編集として動作。
  final Review? existingReview;

  const ReviewEditPage({
    super.key,
    required this.bookId,
    this.existingReview,
  });

  @override
  ConsumerState<ReviewEditPage> createState() => _ReviewEditPageState();
}

class _ReviewEditPageState extends ConsumerState<ReviewEditPage> {
  late final TextEditingController _controller;

  bool get _isEditMode => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.existingReview?.content ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レビュー内容を入力してください')),
      );
      return;
    }

    final notifier = ref.read(reviewListProvider(widget.bookId).notifier);

    if (_isEditMode) {
      await notifier.update(
        widget.existingReview!.copyWith(content: content),
      );
    } else {
      // 新規作成: id は時刻ベースで一意になるよう生成。
      // 厳密な UUID でなくても十分（1 ユーザーの 1 アプリ内で衝突しない粒度）。
      final newReview = Review(
        id: 'review-${DateTime.now().microsecondsSinceEpoch}',
        bookId: widget.bookId,
        content: content,
        createdAt: DateTime.now(),
      );
      await notifier.add(newReview);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isEditMode ? 'レビューを更新しました' : 'レビューを追加しました'),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('レビュー削除'),
        content: const Text('このレビューを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref
        .read(reviewListProvider(widget.bookId).notifier)
        .remove(widget.existingReview!.id);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('レビューを削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'レビュー編集' : 'レビュー追加'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'このレビューを削除',
              onPressed: _confirmAndDelete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: '感想や引用、メモを記録してください',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
    );
  }
}
