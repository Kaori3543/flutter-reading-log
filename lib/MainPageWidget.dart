import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/detail/BookDetail.dart';
import '/list/BookListView.dart';
import 'providers/book_list_provider.dart';

/// 本棚 + 詳細モーダル を Stack で組み合わせる司令塔。
///
/// W1 で大きく変更：
/// - StatefulWidget → ConsumerWidget（Riverpod 経由）
/// - `bool _isSelectedItem` → `selectedBookProvider`（Book?）
///   開閉状態だけでなく「どの本を選んだか」も同時に表現
/// - openDetail / closeDetail コールバック関数 → Riverpod state の直接操作
///
/// なぜ ConsumerWidget か:
/// - state が単一の bool から Book? に変わったが、それを内包する Riverpod
///   provider に切り出したことで、状態の出所が一つに統一された。
/// - 子ウィジェット（BookListView の中で）からも ref.read で state を変更でき、
///   コールバックをバケツリレーする必要がなくなった。
class MainPageWidget extends ConsumerWidget {
  const MainPageWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBook = ref.watch(selectedBookProvider);

    return Stack(
      children: [
        const BookListView(),
        if (selectedBook != null)
          BookDetail(
            book: selectedBook,
            closeAction: () {
              // モーダルを閉じる: 選択を null に戻す
              ref.read(selectedBookProvider.notifier).state = null;
            },
          ),
      ],
    );
  }
}
