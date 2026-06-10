/// 統計画面（W7 で新規追加）。
///
/// 完読本だけを対象に、月別冊数（BarChart）・累計推移（LineChart）・
/// ジャンル別割合（PieChart）を表示する。期間は AppBar 下の TabBar で
/// 直近 6 ヶ月 / 直近 1 年 / 全期間 を切替。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/book_list_provider.dart';
import '../services/stats_calculator.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// 円グラフでジャンル色を順番に割り当てるためのパレット。
  /// Material のサンプルカラーから読みやすい順に選択。
  static const _genrePalette = <Color>[
    Color(0xFF6B4423), // paper-brown（既存テーマ）
    Color(0xFFB07A4E),
    Color(0xFFE3A867),
    Color(0xFF8B7355),
    Color(0xFFA67B5B),
    Color(0xFFD4A574),
    Color(0xFF5C3D2E),
    Color(0xFFC68B59),
  ];

  static const _periods = StatsPeriod.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _periods.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatMonthShort(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${(dt.year % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final period = _periods[_tabController.index];
    final stats = calculateStats(books, period, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: _periods.map((p) => Tab(text: p.label)).toList(),
        ),
      ),
      body: stats.isEmpty
          ? _emptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCards(stats),
                const SizedBox(height: 24),
                _sectionTitle('月別完読数'),
                const SizedBox(height: 8),
                _monthlyBarChart(stats),
                const SizedBox(height: 24),
                _sectionTitle('累計の推移'),
                const SizedBox(height: 8),
                _cumulativeLineChart(stats),
                const SizedBox(height: 24),
                _sectionTitle('ジャンル別の割合'),
                const SizedBox(height: 8),
                _genrePieChart(stats),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'この期間に読了した本がありません',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            '本を「読了」にすると統計が表示されます',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label) => Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      );

  /// 上部に表示する 2 つのサマリ数値カード（期間内総数 + 直近 30 日）。
  Widget _summaryCards(StatsResult stats) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            '期間内の完読',
            '${stats.totalFinished}',
            '冊',
            Icons.menu_book,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '直近 30 日',
            '${stats.recent30DaysCount}',
            '冊',
            Icons.local_fire_department,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.black54),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthlyBarChart(StatsResult stats) {
    final maxCount = stats.monthly
        .map((m) => m.count)
        .fold<int>(0, (a, b) => a > b ? a : b);
    // 棒グラフの Y 軸最大値。最低でも 1 は確保して、0 件月のグラフでも軸が出るように。
    final maxY = (maxCount == 0 ? 1 : maxCount).toDouble() * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: [
            for (int i = 0; i < stats.monthly.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: stats.monthly[i].count.toDouble(),
                    color: const Color(0xFF6B4423),
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
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
                  return Text('${value.toInt()}',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= stats.monthly.length) {
                    return const SizedBox.shrink();
                  }
                  // 全期間でデータ点数が多い場合は間引いて表示。
                  final step = (stats.monthly.length / 6).ceil();
                  if (step > 1 && idx % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatMonthShort(stats.monthly[idx].month),
                      style: const TextStyle(fontSize: 10),
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
            horizontalInterval: maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _cumulativeLineChart(StatsResult stats) {
    final maxY = (stats.cumulative.isEmpty
            ? 1
            : stats.cumulative.last.count == 0
                ? 1
                : stats.cumulative.last.count)
        .toDouble() *
        1.2;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < stats.cumulative.length; i++)
                  FlSpot(i.toDouble(), stats.cumulative[i].count.toDouble()),
              ],
              isCurved: true,
              color: const Color(0xFF6B4423),
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0x336B4423),
              ),
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
                  return Text('${value.toInt()}',
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= stats.cumulative.length) {
                    return const SizedBox.shrink();
                  }
                  final step = (stats.cumulative.length / 6).ceil();
                  if (step > 1 && idx % step != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatMonthShort(stats.cumulative[idx].month),
                      style: const TextStyle(fontSize: 10),
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
            horizontalInterval: maxY <= 5 ? 1 : (maxY / 5).ceilToDouble(),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _genrePieChart(StatsResult stats) {
    if (stats.genres.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const Text(
          'ジャンル情報のある本がまだありません',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final total = stats.genres.fold<int>(0, (sum, g) => sum + g.count);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (int i = 0; i < stats.genres.length; i++)
                  PieChartSectionData(
                    value: stats.genres[i].count.toDouble(),
                    color: _genrePalette[i % _genrePalette.length],
                    title: '${((stats.genres[i].count / total) * 100).round()}%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    radius: 60,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
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
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _genrePalette[i % _genrePalette.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${stats.genres[i].genre} (${stats.genres[i].count})',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
