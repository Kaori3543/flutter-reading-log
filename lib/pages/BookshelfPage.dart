/// 本棚画面（W7 で MainPageWidget から切り出し、W11 で全文検索を追加）。
///
/// W7: AppBar + TabBar + 評価 Chip 帯 + BookListView + 検索 FAB（楽天 API）
/// W11:
///   - AppBar 右側に 🔍 検索アイコン → タップで AppBar title が TextField に
///     切り替わり、本棚内の全文検索ができる
///   - 評価 Chip 帯に「♡だけ」を追加
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

  /// 検索バーの表示状態（W11）。
  bool _isSearching = false;
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) return;
    final status = _tabs[_tabController.index].status;
    ref.read(bookViewSettingsProvider.notifier).setStatusFilter(status);
  }

  /// 検索モードに入る / 出る。
  void _toggleSearchMode() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(bookViewSettingsProvider.notifier).setSearchQuery('');
      }
    });
  }

  void _onSearchChanged(String query) {
    ref.read(bookViewSettingsProvider.notifier).setSearchQuery(query);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(bookViewSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'タイトル / 著者 / 出版社 / レビューを検索',
                  border: InputBorder.none,
                ),
              )
            : const Text('本棚'),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '検索を終了',
                onPressed: _toggleSearchMode,
              )
            : null,
        actions: _isSearching
            ? [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '検索クエリをクリア',
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '本棚内を検索',
                  onPressed: _toggleSearchMode,
                ),
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
          .primaryContainer
          .withValues(alpha: 0.4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ♡だけフィルタ（W11）。評価フィルタの前に置く。
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                avatar: Icon(
                  settings.onlyFavorites
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 16,
                  color: settings.onlyFavorites ? Colors.pink : null,
                ),
                label: const Text('♡だけ'),
                selected: settings.onlyFavorites,
                onSelected: (v) {
                  ref
                      .read(bookViewSettingsProvider.notifier)
                      .setOnlyFavorites(v);
                },
              ),
            ),
            // 区切り
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                height: 24,
                width: 1,
                color: Colors.black26,
              ),
            ),
            // 評価フィルタ
            ..._ratingChoices.map((c) {
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
            }),
          ],
        ),
      ),
    );
  }
}
