/// アプリのルートウィジェット（5 タブ構成）。
///
/// タブ: ホーム / 本棚 / ライブラリ / 発見 / 統計
/// IndexedStack で 5 ページの State を保持。
/// 下部ナビゲーションはアクティブ時に accent pill を表示するカスタムバー。
library;

import 'package:flutter/material.dart';
import 'pages/BookshelfPage.dart';
import 'pages/DiscoverPage.dart';
import 'pages/HomePage.dart';
import 'pages/LibraryPage.dart';
import 'pages/StatsPage.dart';
import 'theme/app_theme.dart';

class MainPageWidget extends StatefulWidget {
  const MainPageWidget({super.key});

  @override
  State<MainPageWidget> createState() => _MainPageWidgetState();
}

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab({required this.icon, required this.label});
}

const _tabs = <_NavTab>[
  _NavTab(icon: Icons.home_outlined, label: 'ホーム'),
  _NavTab(icon: Icons.menu_book_outlined, label: '本棚'),
  _NavTab(icon: Icons.library_books_outlined, label: 'ライブラリ'),
  _NavTab(icon: Icons.explore_outlined, label: '発見'),
  _NavTab(icon: Icons.bar_chart_outlined, label: '統計'),
];

class _MainPageWidgetState extends State<MainPageWidget> {
  int _index = 0;

  /// 初期タブ (ホーム) のみ即時ビルド。他タブは初回タップまで
  /// プレースホルダにしておき、表示された瞬間に initState が走るように
  /// する (統計ページの登場アニメーションを可視化するため)。
  final Set<int> _visited = {0};

  /// 統計タブに切り替わるたびに +1 して、統計 StatsPage を key で再生成する。
  /// これで開き直すたびに initState が走り、登場アニメが毎回再生される。
  int _statsVisitCount = 0;

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return const HomePage();
      case 1:
        return const BookshelfPage();
      case 2:
        return const LibraryPage();
      case 3:
        return const DiscoverPage();
      case 4:
        return StatsPage(key: ValueKey('stats_$_statsVisitCount'));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: List.generate(_tabs.length, (i) {
          if (_visited.contains(i)) return _pageFor(i);
          return const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final tab = _tabs[i];
            final active = _index == i;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() {
                  _index = i;
                  _visited.add(i);
                  // 統計タブに切り替えるたびにカウンタ +1 → key 更新で
                  // StatsPage が再生成され、初回描画アニメが再生される。
                  if (i == 4) _statsVisitCount++;
                }),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (active)
                      Container(
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(tab.icon,
                            size: 17, color: AppColors.fg),
                      )
                    else
                      Icon(tab.icon, size: 20, color: AppColors.mutedFg),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            active ? AppColors.fg : AppColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
