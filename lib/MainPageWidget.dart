/// アプリのルートウィジェット（W7 で BottomNavigationBar の親に変更）。
///
/// W1〜W6: AppBar + 本棚画面の全機能をここに集約していた
/// W7: 機能ごとにページを分け、BottomNavigationBar で切替えるようリファクタ。
///     - 本棚: BookshelfPage（旧 MainPageWidget の本棚 UI を移動）
///     - 統計: StatsPage（新規）
/// W8: 発見タブを追加（DiscoverPage）。楽天 Books の売れ筋ランキングを
///     ジャンル別に表示し、本棚に取り込めるようにした。
/// IndexedStack で 3 ページの State（TabController や Future）を保持する。
library;

import 'package:flutter/material.dart';
import 'pages/BookshelfPage.dart';
import 'pages/DiscoverPage.dart';
import 'pages/StatsPage.dart';

class MainPageWidget extends StatefulWidget {
  const MainPageWidget({super.key});

  @override
  State<MainPageWidget> createState() => _MainPageWidgetState();
}

class _MainPageWidgetState extends State<MainPageWidget> {
  int _index = 0;

  static const _pages = [
    BookshelfPage(),
    DiscoverPage(),
    StatsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '本棚',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '発見',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '統計',
          ),
        ],
      ),
    );
  }
}
