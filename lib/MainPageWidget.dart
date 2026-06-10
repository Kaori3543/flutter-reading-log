/// 本棚画面 + 検索 FAB + 表示設定 UI を組み合わせる司令塔。
///
/// W1〜W3: Stack で BookListView と BookDetail（条件付き）を重ねる
/// W4: BookDetail を Navigator.push に移して Stack 撤去
/// W6:
///   - DefaultTabController + TabBar でステータス別に本棚を分離
///   - AppBar の actions にソート選択 PopupMenuButton
///   - TabBar 直下に評価フィルタ用の ChoiceChip 帯
///   - タブ切替・評価フィルタ・ソート変更は bookViewSettingsProvider に反映
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/list/BookListView.dart';
import 'models/book.dart';
import 'pages/SearchPage.dart';
import 'providers/book_view_settings_provider.dart';

/// 本棚 TabBar のタブ定義。
class _BookTab {
  final String label;
  final BookStatus? status;
  const _BookTab(this.label, this.status);
}

const List<_BookTab> _tabs = [
  _BookTab('全て', null),
  _BookTab('読みたい', BookStatus.wantToRead),
  _BookTab('読書中', BookStatus.reading),
  _BookTab('読了', BookStatus.finished),
];

/// 評価フィルタの選択肢。
class _RatingChoice {
  final String label;
  final double minRating;
  const _RatingChoice(this.label, this.minRating);
}

const List<_RatingChoice> _ratingChoices = [
  _RatingChoice('すべて', 0.0),
  _RatingChoice('★3以上', 3.0),
  _RatingChoice('★4以上', 4.0),
  _RatingChoice('★5', 5.0),
];

class MainPageWidget extends ConsumerStatefulWidget {
  const MainPageWidget({super.key});

  @override
  ConsumerState<MainPageWidget> createState() => _MainPageWidgetState();
}

class _MainPageWidgetState extends ConsumerState<MainPageWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // アニメーション中は addListener が複数回呼ばれるが、indexIsChanging
    // で確定タイミングだけを拾う。
    if (!_tabController.indexIsChanging) return;
    final status = _tabs[_tabController.index].status;
    ref.read(bookViewSettingsProvider.notifier).setStatusFilter(status);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(bookViewSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('本棚'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<BookSort>(
            icon: const Icon(Icons.sort),
            tooltip: '並び替え',
            initialValue: settings.sort,
            onSelected: (sort) =>
                ref.read(bookViewSettingsProvider.notifier).setSort(sort),
            itemBuilder: (context) => BookSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          if (settings.sort == s)
                            const Icon(Icons.check, size: 16)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
              ),
              _ratingFilterBar(settings),
            ],
          ),
        ),
      ),
      body: const BookListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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

  Widget _ratingFilterBar(BookViewSettings settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.inversePrimary.withValues(alpha: 0.4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ratingChoices.map((c) {
            final selected = settings.minRating == c.minRating;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(c.label),
                selected: selected,
                onSelected: (_) {
                  if (!selected) {
                    ref
                        .read(bookViewSettingsProvider.notifier)
                        .setMinRating(c.minRating);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
