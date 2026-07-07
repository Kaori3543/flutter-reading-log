/// 発見タブ（W8 で新規追加）。
///
/// 楽天 Books API の Search + sort=sales で「売れている順」を取得し、
/// 全ジャンル + 人気の小説 + 人気のビジネス書 + 人気のコミックを
/// 縦に 4 セクション並べる。各セクションは横スクロールで本棚と同じ
/// 縦カードを表示、カードタップで BottomSheet 詳細 → 本棚に追加。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../list/BookListItem.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../services/rakuten_api.dart';
import '../theme/app_theme.dart';
import '../widgets/BookDetailBottomSheet.dart';

/// セクション定義: ヘッダタイトル + アイコン + 楽天 Books のジャンル ID。
class _DiscoverSection {
  final String title;
  final IconData icon;
  final String booksGenreId;
  const _DiscoverSection({
    required this.title,
    required this.icon,
    required this.booksGenreId,
  });
}

/// 表示するセクションのリスト。
/// "001" が本全体、"001004" が小説・エッセイ、"001006" がビジネス、
/// "001001" がコミック。楽天 Books の booksGenreId 体系に準拠。
const List<_DiscoverSection> _sections = [
  _DiscoverSection(
    title: '今話題の本（売れ筋）',
    icon: Icons.trending_up,
    booksGenreId: '001',
  ),
  _DiscoverSection(
    title: '人気の小説・エッセイ',
    icon: Icons.menu_book_outlined,
    booksGenreId: '001004',
  ),
  _DiscoverSection(
    title: '人気のビジネス書',
    icon: Icons.business_center_outlined,
    booksGenreId: '001006',
  ),
  _DiscoverSection(
    title: '人気のコミック',
    icon: Icons.auto_stories_outlined,
    booksGenreId: '001001',
  ),
];

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _api = RakutenApi();

  /// 各セクションのランキング取得 Future。section.booksGenreId をキーに保持。
  ///
  /// 楽天 API のレート制限（1 リクエスト/秒）を踏まないように、4 並列ではなく
  /// 1.1 秒間隔の逐次実行で取得する。各セクションには Completer で「未完了の
  /// Future」を割り当て、UI 側は最初から FutureBuilder で待機状態を表示
  /// できるようにする。先頭のセクションから順番に解決される。
  late final Map<String, Future<List<RankingItem>>> _futures;

  final Map<String, Completer<List<RankingItem>>> _completers = {};

  @override
  void initState() {
    super.initState();
    for (final s in _sections) {
      _completers[s.booksGenreId] = Completer<List<RankingItem>>();
    }
    _futures = {
      for (final s in _sections)
        s.booksGenreId: _completers[s.booksGenreId]!.future,
    };
    _loadSequentially();
  }

  /// セクションを 1 つずつ取得して Completer を完了させる。
  /// API 1 回ごとに 1.1 秒待ってからレート制限を越えないようにする。
  Future<void> _loadSequentially() async {
    for (int i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      try {
        final result = await _api.searchRanking(booksGenreId: s.booksGenreId);
        if (!_completers[s.booksGenreId]!.isCompleted) {
          _completers[s.booksGenreId]!.complete(result);
        }
      } catch (e) {
        if (!_completers[s.booksGenreId]!.isCompleted) {
          _completers[s.booksGenreId]!.completeError(e);
        }
      }
      // 最後のセクションの後は待つ必要なし
      if (i < _sections.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1100));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('発見'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
          return _RankingSection(
            section: section,
            future: _futures[section.booksGenreId]!,
            api: _api,
            isLast: index == _sections.length - 1,
          );
        },
      ),
    );
  }
}

class _RankingSection extends ConsumerWidget {
  final _DiscoverSection section;
  final Future<List<RankingItem>> future;
  final RakutenApi api;
  final bool isLast;

  const _RankingSection({
    required this.section,
    required this.future,
    required this.api,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクション見出し (ホームと同じ accent アイコン + セミボールド)。
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(section.icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: FutureBuilder<List<RankingItem>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ランキング取得に失敗しました\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                );
              }
              final items = snapshot.data ?? const <RankingItem>[];
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    '取得結果が空でした',
                    style: TextStyle(color: AppColors.mutedFg),
                  ),
                );
              }
              return _horizontalList(context, ref, items);
            },
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(height: 1, color: AppColors.border),
          ),
      ],
    );
  }

  Widget _horizontalList(
    BuildContext context,
    WidgetRef ref,
    List<RankingItem> items,
  ) {
    final shelfBookIds =
        ref.watch(bookListProvider).map((b) => b.id).toSet();

    return AnimationLimiter(
      key: ValueKey('discover-${items.length}'),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 420),
            child: SlideAnimation(
              horizontalOffset: 40,
              child: FadeInAnimation(
                child: _RankingCard(
                  rank: index + 1,
                  book: item.book,
                  caption: item.caption,
                  alreadyAdded: shelfBookIds.contains(item.book.id),
                  onTap: () => showBookDetailSheet(
                    context,
                    ref: ref,
                    book: item.book,
                    api: api,
                    caption: item.caption,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 発見タブのカード。本棚と同じ縦カード (BookListItem compact) をベースに、
/// ランキングバッジと「本棚に登録済み」バッジを Stack で上に重ねる。
class _RankingCard extends StatelessWidget {
  final int rank;
  final Book book;
  final String? caption;
  final bool alreadyAdded;
  final VoidCallback onTap;

  const _RankingCard({
    required this.rank,
    required this.book,
    required this.caption,
    required this.alreadyAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 145,
        child: Stack(
          children: [
            BookListItem(
              book: book,
              compact: true,
              showActionButton: false,
              showRating: false,
              showStatusBadge: false,
              onPressed: onTap,
            ),
            // ランキングバッジ (カバー左上)。
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: rank <= 3 ? AppColors.accent : Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$rank位',
                  style: TextStyle(
                    color: rank <= 3 ? AppColors.fg : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // 本棚に登録済みバッジ (カバー右上)。
            if (alreadyAdded)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
