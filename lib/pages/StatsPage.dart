/// 統計画面 (UI 刷新版)。
///
/// 3 セクションに絞ってスッキリと。
///   1. 月別完読数 (棒グラフ、年切替可能、直近 12 ヶ月分)
///   2. ジャンル別の割合 (円グラフ、選択した年の完読本のみ)
///   3. お気に入り著者 TOP5 (全期間、年の影響なし)
///
/// 上部に年セレクタを置き、1〜2 のセクションが連動して更新される。
/// お気に入り著者は嗜好の傾向として全期間集計にする。
///
/// UI: AppColors + section header は accent アイコン (ホームと統一)。
/// グラフには fl_chart の swapAnimationDuration によるスムーズなアニメーション。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/book_list_provider.dart';
import '../services/stats_calculator.dart';
import '../theme/app_theme.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int? _selectedYear;

  /// 初回描画時にグラフを 0 → 実データにアニメさせるためのフラグ。
  /// initState → 直後に true にすると fl_chart の swap アニメが発火する。
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // 少し遅らせることで、まず 0 の状態が 1 フレーム見えてから
    // 実データへ遷移するので fl_chart の swap アニメが確実に発火する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _revealed = true);
      });
    });
  }

  /// ジャンル色パレット (warm brown 系で統一)。
  static const _genrePalette = <Color>[
    AppColors.primary,
    AppColors.accent,
    Color(0xFFB07A4E),
    Color(0xFF8B7355),
    Color(0xFFA67B5B),
    Color(0xFFD4A574),
    Color(0xFF5C3D2E),
    Color(0xFFC68B59),
  ];

  static const _monthLabels = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'
  ];

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final now = DateTime.now();
    final years = availableYears(books, currentYear: now.year);
    final selected = _selectedYear ?? years.first;
    final stats = calculateYearlyStats(books, selected);

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _yearSelector(years, selected),
          const SizedBox(height: 12),
          _sectionHeader(
            icon: Icons.bar_chart_outlined,
            title: '月別完読数',
            subtitle: '$selected 年に読了した本の月別冊数',
          ),
          _monthlyBarSection(stats),
          _divider(),
          _sectionHeader(
            icon: Icons.pie_chart_outline,
            title: 'ジャンル別の割合',
            subtitle: '$selected 年に読了した本のジャンル比率',
          ),
          _genrePieSection(stats),
          _divider(),
          _sectionHeader(
            icon: Icons.favorite,
            iconColor: AppColors.favoritePink,
            title: 'お気に入り著者 TOP5',
            subtitle: '全期間 (★4.0 以上を高評価としてカウント)',
          ),
          _favoriteAuthorsSection(stats),
        ],
      ),
    );
  }

  // ── 年セレクタ (← 2026 → 型のナビ) ───────────────────
  Widget _yearSelector(List<int> years, int selected) {
    final index = years.indexOf(selected);
    // years は新しい順ソート → 「1 つ古い年」= index + 1、「1 つ新しい年」= index - 1
    final canGoOlder = index >= 0 && index < years.length - 1;
    final canGoNewer = index > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _arrowButton(
            icon: Icons.chevron_left,
            enabled: canGoOlder,
            onTap: () =>
                setState(() => _selectedYear = years[index + 1]),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '$selected 年',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryFg,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _arrowButton(
            icon: Icons.chevron_right,
            enabled: canGoNewer,
            onTap: () =>
                setState(() => _selectedYear = years[index - 1]),
          ),
        ],
      ),
    );
  }

  Widget _arrowButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled
          ? AppColors.secondary
          : AppColors.secondary.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.mutedFg
                .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ── セクション見出し ──────────────────────────────
  Widget _sectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
    Color iconColor = AppColors.accent,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fg,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 23),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedFg,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(height: 1, color: AppColors.border),
    );
  }

  // ── 月別完読数 ─────────────────────────────────────
  Widget _monthlyBarSection(YearlyStatsResult stats) {
    if (stats.totalFinished == 0) {
      return _emptyCard(
        icon: Icons.bar_chart_outlined,
        message: 'この年の完読本はまだありません',
      );
    }
    final maxCount = stats.monthly
        .map((m) => m.count)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = (maxCount == 0 ? 1 : maxCount).toDouble() * 1.25;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          BarChartData(
            maxY: maxY,
            barGroups: [
              for (int i = 0; i < 12; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: _revealed
                          ? stats.monthly[i].count.toDouble()
                          : 0.0,
                      color: AppColors.accent,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: AppColors.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
            ],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
                  getTitlesWidget: (value, meta) {
                    if (value != value.roundToDouble()) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      '${value.toInt()}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.mutedFg),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= 12) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _monthLabels[idx],
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mutedFg,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.primary,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${_monthLabels[group.x]} 月\n${rod.toY.toInt()} 冊',
                    const TextStyle(
                      color: AppColors.primaryFg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── ジャンル別 (円グラフ) ─────────────────────────
  Widget _genrePieSection(YearlyStatsResult stats) {
    if (stats.genres.isEmpty) {
      return _emptyCard(
        icon: Icons.pie_chart_outline,
        message: 'ジャンル情報のある本がまだありません',
      );
    }
    final total = stats.genres.fold<int>(0, (sum, g) => sum + g.count);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: PieChart(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (int i = 0; i < stats.genres.length; i++)
                    PieChartSectionData(
                      value: stats.genres[i].count.toDouble(),
                      color: _genrePalette[i % _genrePalette.length],
                      title: _revealed
                          ? '${((stats.genres[i].count / total) * 100).round()}%'
                          : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      radius: _revealed ? 55 : 0.5,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < stats.genres.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                _genrePalette[i % _genrePalette.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            stats.genres[i].genre,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.fg,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${stats.genres[i].count})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── お気に入り著者 TOP5 ─────────────────────────
  Widget _favoriteAuthorsSection(YearlyStatsResult stats) {
    if (stats.favoriteAuthors.isEmpty) {
      return _emptyCard(
        icon: Icons.person_outline,
        message: '★4.0 以上をつけた本の著者がまだいません',
      );
    }
    final top = stats.favoriteAuthors.take(5).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(top.length, (i) {
          final s = top[i];
          final isLast = i == top.length - 1;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.accent
                        : AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: i == 0
                          ? AppColors.fg
                          : AppColors.mutedFg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.author,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '★ ${s.averageFavoriteRating.toStringAsFixed(1)}  ・  高評価 ${s.favoriteCount} 冊',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String message}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.mutedFg),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}
