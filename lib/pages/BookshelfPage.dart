/// 本棚画面（W7 で MainPageWidget から切り出し、W11 で全文検索を追加）。
///
/// W7: AppBar + TabBar + 評価 Chip 帯 + BookListView + 検索 FAB（楽天 API）
/// W11:
///   - AppBar 右側に 🔍 検索アイコン → タップで AppBar title が TextField に
///     切り替わり、本棚内の全文検索ができる
///   - 評価 Chip 帯に「♡だけ」を追加
/// UI 改修:
///   - ステータスタブ + ★評価 Chip 帯を廃止し、AppBar 右上の
///     「フィルタ」ボタン → BottomSheet に集約
///   - BottomSheet で「ステータス / ★評価 / ♡だけ」を一括設定できる
///   - フィルタ適用中は AppBar 直下に選択中サマリー行を表示、× で個別解除
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../list/BookListView.dart';
import '../models/book.dart';
import '../providers/book_view_settings_provider.dart';
import '../theme/app_theme.dart';
import 'SearchPage.dart';

/// ステータスフィルタ選択肢（BottomSheet 内 Chip）。
class _StatusChoice {
  final String label;
  final BookStatus? status;
  const _StatusChoice(this.label, this.status);
}

const List<_StatusChoice> _statusChoices = [
  _StatusChoice('全て', null),
  _StatusChoice('読みたい', BookStatus.wantToRead),
  _StatusChoice('読書中', BookStatus.reading),
  _StatusChoice('読了', BookStatus.finished),
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

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  /// 検索バーの表示状態（W11）。
  bool _isSearching = false;
  final _searchController = TextEditingController();

  /// フィルタボタンの位置取得用。showMenu で「ボタンの下」に出すため。
  final GlobalKey _filterButtonKey = GlobalKey();

  /// 並び替えボタンの位置取得用。フィルタと揃えて自前 showMenu にする。
  final GlobalKey _sortButtonKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  /// ステータスラベル（サマリー Chip 用）。
  String _statusLabel(BookStatus s) {
    switch (s) {
      case BookStatus.wantToRead:
        return '読みたい';
      case BookStatus.reading:
        return '読書中';
      case BookStatus.finished:
        return '読了';
    }
  }

  String _ratingLabel(double r) {
    if (r >= 5.0) return '★5';
    if (r >= 4.0) return '★4以上';
    if (r >= 3.0) return '★3以上';
    return '';
  }

  /// フィルタメニューをボタン直下にポップアップ表示する（並び替えと同じ挙動）。
  Future<void> _openFilterSheet() async {
    final button = _filterButtonKey.currentContext?.findRenderObject()
        as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    const menuWidth = 320.0;
    final buttonBottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    await showMenu<void>(
      context: context,
      color: AppColors.bg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      // 右寄せで、ボタンの真下 (少しオフセット) に出す。
      position: RelativeRect.fromLTRB(
        buttonBottomRight.dx - menuWidth,
        buttonBottomRight.dy + 4,
        overlay.size.width - buttonBottomRight.dx,
        0,
      ),
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: menuWidth,
            child: const _FilterMenuContent(),
          ),
        ),
      ],
    );

    if (mounted) setState(() {}); // ドットの再描画用
  }

  /// 並び替えメニューをボタン直下にポップアップ表示する。
  Future<void> _openSortMenu() async {
    final button =
        _sortButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    const menuWidth = 220.0;
    final buttonBottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    await showMenu<void>(
      context: context,
      color: AppColors.bg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(
        buttonBottomRight.dx - menuWidth,
        buttonBottomRight.dy + 4,
        overlay.size.width - buttonBottomRight.dx,
        0,
      ),
      constraints: const BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: menuWidth,
            child: const _SortMenuContent(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(bookViewSettingsProvider);
    final hasActiveFilter = settings.statusFilter != null ||
        settings.minRating > 0.0 ||
        settings.onlyFavorites;

    return Scaffold(
      appBar: AppBar(
        // アクション 4 個ぶんの幅で右寄せになるので、通常の centerTitle だけ
        // では画面中央には来ない。検索中でないときは flexibleSpace 側で
        // AppBar 全幅に対して中央にラベルを描き、title は空にする。
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                // ヘッダーがダーク茶背景なので、入力文字と placeholder は
                // 白系にコントラストを取る (デフォルトのままだと fg #2C2416
                // が背景と近くて読めない)。
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'タイトル / 著者 / 出版社 / レビューを検索',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
              )
            : null,
        flexibleSpace: _isSearching
            ? null
            : SafeArea(
                child: Center(
                  child: Text(
                    '本棚',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                ),
              ),
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
                // アクションを compact に詰めて、中央の「本棚」タイトルとの
                // 距離を確保する。default の IconButton は 48x48 だが
                // visualDensity: compact + 小さめ padding で ~36 幅にする。
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: '本棚内を検索',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  onPressed: _toggleSearchMode,
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      key: _filterButtonKey,
                      icon: const Icon(Icons.tune),
                      tooltip: 'フィルタ',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      onPressed: _openFilterSheet,
                    ),
                    if (hasActiveFilter)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  key: _sortButtonKey,
                  icon: const Icon(Icons.sort),
                  tooltip: '並び替え',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  onPressed: _openSortMenu,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '本棚に新しく追加',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SearchPage()),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
        bottom: hasActiveFilter
            ? PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: _filterSummaryBar(settings),
              )
            : null,
      ),
      body: const BookListView(),
    );
  }

  /// AppBar 直下の「選択中フィルタ」サマリー行。
  /// 各 Chip の × タップでその条件だけ解除。「クリア」で全解除。
  Widget _filterSummaryBar(BookViewSettings settings) {
    final notifier = ref.read(bookViewSettingsProvider.notifier);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppColors.secondary.withValues(alpha: 0.5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (settings.statusFilter != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InputChip(
                  label: Text(_statusLabel(settings.statusFilter!)),
                  onDeleted: () => notifier.setStatusFilter(null),
                ),
              ),
            if (settings.minRating > 0.0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InputChip(
                  label: Text(_ratingLabel(settings.minRating)),
                  onDeleted: () => notifier.setMinRating(0.0),
                ),
              ),
            if (settings.onlyFavorites)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InputChip(
                  avatar: const Icon(Icons.favorite,
                      size: 14, color: AppColors.favoritePink),
                  label: const Text('♡だけ'),
                  onDeleted: () => notifier.setOnlyFavorites(false),
                ),
              ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () {
                notifier.setStatusFilter(null);
                notifier.setMinRating(0.0);
                notifier.setOnlyFavorites(false);
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('クリア'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// フィルタメニューの中身（フィルタボタン直下にポップアップ表示）。
/// ステータス / ★評価 / ♡だけ を 1 画面で設定。変更は即時 provider に反映。
/// メニューを閉じるにはメニュー外をタップ（並び替えメニューと同じ挙動）。
class _FilterMenuContent extends ConsumerWidget {
  const _FilterMenuContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(bookViewSettingsProvider);
    final notifier = ref.read(bookViewSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 並び替えメニューの見出しと同じ small letterSpacing の
              // muted スタイルに統一する。
              const Text(
                'フィルタ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: AppColors.mutedFg,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  notifier.setStatusFilter(null);
                  notifier.setMinRating(0.0);
                  notifier.setOnlyFavorites(false);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('すべて解除'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionLabel('ステータス'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statusChoices.map((c) {
              final selected = settings.statusFilter == c.status;
              return _pillChoice(
                label: c.label,
                selected: selected,
                onTap: () {
                  if (!selected) notifier.setStatusFilter(c.status);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _sectionLabel('評価'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ratingChoices.map((c) {
              final selected = settings.minRating == c.minRating;
              return _pillChoice(
                label: c.label,
                selected: selected,
                onTap: () {
                  if (!selected) notifier.setMinRating(c.minRating);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _sectionLabel('お気に入り'),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('♡ を付けた本だけ表示',
                style: TextStyle(color: AppColors.fg, fontSize: 13)),
            value: settings.onlyFavorites,
            activeThumbColor: AppColors.primaryFg,
            activeTrackColor: AppColors.primary,
            onChanged: (v) => notifier.setOnlyFavorites(v),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.2,
        color: AppColors.mutedFg,
      ),
    );
  }

  Widget _pillChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.secondary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primaryFg : AppColors.mutedFg,
          ),
        ),
      ),
    );
  }
}

/// 並び替えメニューの中身（並び替えボタン直下にポップアップ表示）。
/// フィルタメニューと見た目・フォントを統一するため、
/// 「並び替え」見出し + pill 選択肢の Wrap で構成。
class _SortMenuContent extends ConsumerWidget {
  const _SortMenuContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(bookViewSettingsProvider);
    final notifier = ref.read(bookViewSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '並び替え',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
              color: AppColors.mutedFg,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BookSort.values.map((s) {
              final selected = settings.sort == s;
              return InkWell(
                onTap: () {
                  if (!selected) notifier.setSort(s);
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        selected ? AppColors.primary : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.primaryFg
                          : AppColors.mutedFg,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
