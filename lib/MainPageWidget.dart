import 'package:flutter/material.dart';
import '/list/BookListView.dart';
import 'pages/SearchPage.dart';

/// 本棚画面 + 検索 FAB を組み合わせる司令塔。
///
/// W1〜W3: Stack で BookListView と BookDetail（条件付き）を重ねる構造
/// W4: BookDetail を Navigator.push の独立ページに移したため、Stack を撤去。
///     body は BookListView のみ、FAB で SearchPage に遷移、本棚タップで
///     BookDetail に遷移（BookListView 内で Navigator.push）。
///
/// state を持たなくなったので StatelessWidget に戻した（Riverpod の ref も
/// 不要）。
class MainPageWidget extends StatelessWidget {
  const MainPageWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const BookListView(),
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
