import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/detail/BookDetail.dart';
import '/list/BookListView.dart';
import 'pages/SearchPage.dart';
import 'providers/book_list_provider.dart';

/// 本棚 + 詳細モーダル + 検索 FAB を組み合わせる司令塔。
///
/// W1: Stack の上に BookListView と BookDetail（条件付き）を載せる構造に。
/// W2: Scaffold でラップして検索 FAB を追加し、Navigator.push で SearchPage
///     に遷移できるようにした。
///
/// なぜ Scaffold でラップしたか:
/// - FAB を表示するには Scaffold が必要
/// - 将来 AppBar や Drawer を入れる際にも基盤になる
///
/// なぜ Navigator.push（新しい画面）で SearchPage に遷移するか:
/// - 検索画面は本棚画面とは独立した役割の画面
/// - 標準的な「戻る」操作（Android の戻るボタン、iOS のスワイプ）で
///   本棚画面に戻れるようにしたい
/// - Flutter 特性として Navigator.push の使い方を体得する目的もある
class MainPageWidget extends ConsumerWidget {
  const MainPageWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBook = ref.watch(selectedBookProvider);

    return Scaffold(
      body: Stack(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // W2: 検索画面を新しい画面として開く（Navigator.push）。
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchPage()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        tooltip: '本を検索',
        child: const Icon(Icons.search),
      ),
    );
  }
}
