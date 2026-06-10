/// 本棚画面（W7 で MainPageWidget から切り出し）。
///
/// 以前 MainPageWidget が直接持っていた以下の UI を担当する:
///   - AppBar（タイトル「本棚」+ 並び替え PopupMenuButton）
///   - TabBar（全て / 読みたい / 読書中 / 読了）
///   - 評価フィルタ Chip 帯
///   - 本棚一覧（BookListView）
///   - 検索 FAB
///
/// W7 では MainPageWidget が BottomNavigationBar に変わり、本棚と統計の
/// 切替の親になったため、本棚側のロジックを独立ページに移した。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../list/BookListView.dart';
import '../models/book.dart';
import '../providers/book_view_settings_provider.dart';
import 'SearchPage.dart';

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

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage>
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
      color: Theme.of(context)
          .colorScheme
          .inversePrimary
          .withValues(alpha: 0.4),
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
