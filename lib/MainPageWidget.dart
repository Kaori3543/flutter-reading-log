/// アプリのルートウィジェット（W9 で 4 タブ構成に拡張）。
///
/// W1〜W6: AppBar + 本棚画面の全機能をここに集約していた
/// W7: 機能ごとにページを分け、BottomNavigationBar で切替（本棚 / 統計）
/// W8: 「発見」タブを追加（楽天売れ筋ランキング）
/// W9: 「ホーム」タブを追加（ダッシュボード: 目標 / リマインダー / おすすめ）
///     初期表示タブを本棚 → ホームに変更
/// IndexedStack で 4 ページの State（TabController や Future）を保持する。
library;

import 'package:flutter/material.dart';
import 'pages/BookshelfPage.dart';
import 'pages/DiscoverPage.dart';
import 'pages/HomePage.dart';
import 'pages/StatsPage.dart';

class MainPageWidget extends StatefulWidget {
  const MainPageWidget({super.key});

  @override
  State<MainPageWidget> createState() => _MainPageWidgetState();
}

class _MainPageWidgetState extends State<MainPageWidget> {
  int _index = 0;

  static const _pages = [
    HomePage(),
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
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
