/// ホームタブ（W9 で新規追加）。
///
/// アプリ起動時の入口となるダッシュボード画面。以下のセクションを縦並びで表示:
///   1. 今月の読書目標サマリ（E2）
///   2. 読みかけの本 — 進捗が止まっている本（R6）
///   3. そろそろ読みませんか？ — 積読放置（R5）
///   4. あなたへのおすすめ — お気に入り著者の他作品 + よく読むジャンルの売れ筋（R1）
///
/// 該当本ゼロのセクションは非表示にしてごちゃつかない設計。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../detail/BookDetail.dart';
import '../list/BookListItem.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../theme/app_theme.dart';
import '../providers/reading_goal_provider.dart';
import '../services/auth_service.dart';
import '../services/personalized_recommendations.dart';
import '../services/rakuten_api.dart';
import '../services/reminders.dart';
import '../widgets/BookDetailBottomSheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _api = RakutenApi();

  /// 「あなたへのおすすめ」の各サブセクション Future（W8 と同じ Completer 方式）。
  /// キーは `"author:{name}"` と `"genre:{id}"` の 2 種。
  final Map<String, Completer<List<RankingItem>>> _recommendationCompleters = {};
  Map<String, Future<List<RankingItem>>> _recommendationFutures = {};

  /// 直近にロードを開始したお気に入り著者・ジャンルキー（再ロード判定に使う）。
  Set<String> _lastRecommendationKeys = const {};

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(bookListProvider);
    final goal = ref.watch(readingGoalProvider);
    final now = DateTime.now();
    final reminders = collectReminders(books, now);

    final thisMonthCount = books.where((b) {
      final f = b.finishedAt;
      return b.status == BookStatus.finished &&
          f != null &&
          f.year == now.year &&
          f.month == now.month;
    }).length;

    // R1: お気に入り著者の上位 1 名 + よく読むジャンル ID の上位 1 個から
    // おすすめ取得。本棚の内容が変わったら必要に応じて再ロード。
    final favAuthors = collectFavoriteAuthors(books);
    final favGenreIds = collectFavoriteGenreIds(books);
    final topAuthor = favAuthors.isNotEmpty ? favAuthors.first.author : null;
    final topGenreId = favGenreIds.isNotEmpty ? favGenreIds.first : null;
    final desiredKeys = <String>{
      if (topAuthor != null) 'author:$topAuthor',
      if (topGenreId != null) 'genre:$topGenreId',
    };
    if (!_setEquals(desiredKeys, _lastRecommendationKeys)) {
      _scheduleRecommendationLoad(topAuthor, topGenreId);
      _lastRecommendationKeys = desiredKeys;
    }

    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
        actions: [
          if (user != null)
            PopupMenuButton<String>(
              tooltip: 'アカウント',
              icon: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.accent,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 16, color: AppColors.fg)
                    : null,
              ),
              onSelected: (v) async {
                if (v == 'signout') {
                  await ref.read(authServiceProvider).signOut();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName ?? 'ログイン中',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.fg,
                        ),
                      ),
                      if (user.email != null)
                        Text(
                          user.email!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.mutedFg,
                          ),
                        ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'signout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 16, color: AppColors.mutedFg),
                      SizedBox(width: 8),
                      Text('ログアウト'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _goalCard(context, goal: goal, thisMonth: thisMonthCount),
          // W11 ではお気に入り本セクションをここに置いていたが、W12 で
          // 「ライブラリ」タブを新設したため、お気に入りはそちらに集約した
          // （ホーム = 今日の体験、ライブラリ = 自分の分類 という役割分担）。
          if (reminders.stalledReading.isNotEmpty)
            _bookListSection(
              context,
              title: '読みかけの本',
              icon: Icons.access_time,
              subtitle: '読書開始から 1 ヶ月以上経っています',
              books: reminders.stalledReading,
            ),
          if (reminders.stalledWantToRead.isNotEmpty)
            _bookListSection(
              context,
              title: 'そろそろ読みませんか？',
              icon: Icons.local_library_outlined,
              subtitle: '本棚に追加してから 3 ヶ月以上経っています',
              books: reminders.stalledWantToRead,
            ),
          if (topAuthor != null)
            _recommendationSection(
              context,
              title: 'お気に入り著者「$topAuthor」の他の作品',
              icon: Icons.person_search,
              futureKey: 'author:$topAuthor',
              subtitle: '本詳細で♡を付けた著者から',
            ),
          if (topGenreId != null)
            _recommendationSection(
              context,
              title: 'よく読むジャンルの売れ筋',
              icon: Icons.auto_awesome,
              futureKey: 'genre:$topGenreId',
              subtitle: '完読した本のジャンルから',
            ),
          // 全部空のときの fallback メッセージ。
          // 本棚が空（新規ユーザー）か、本棚に本はあるがリマインダー条件を
          // 満たしていないだけかで文言を出し分ける。
          if (reminders.isEmpty && topAuthor == null && topGenreId == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  books.isEmpty
                      ? '本棚に本を追加すると、ここにおすすめやリマインダーが表示されます'
                      : 'リマインダーやおすすめの条件を満たす本がまだありません',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 月間読書目標 + 今月の完読数 + 達成率カード。
  Widget _goalCard(BuildContext context,
      {required int? goal, required int thisMonth}) {
    final pct = (goal != null && goal > 0)
        ? (thisMonth / goal).clamp(0.0, 1.0)
        : 0.0;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行: アイコン + 見出し + 変更ボタン
          Row(
            children: [
              const Icon(Icons.flag_outlined,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text(
                '今月の読書目標',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fg,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _editGoal(context, current: goal),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    goal == null ? '目標を設定' : '変更',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedFg,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (goal == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'まだ目標が設定されていません',
                style: TextStyle(fontSize: 13, color: AppColors.mutedFg),
              ),
            )
          else ...[
            // 大きな数字 + 「/ N 冊」 + パーセントピル
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$thisMonth',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ $goal 冊',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.mutedFg,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${(pct * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // グラデーションのプログレスバー (accent → #B8894E)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 10,
                color: AppColors.secondary,
                child: FractionallySizedBox(
                  widthFactor: pct.clamp(0.02, 1.0),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [AppColors.accent, Color(0xFFB8894E)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pct >= 1.0
                  ? '今月の目標を達成しました！'
                  : 'あと ${goal - thisMonth} 冊で目標達成！今月も頑張りましょう。',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedFg),
            ),
          ],
        ],
      ),
    );
  }

  /// 「目標を設定 / 変更」ダイアログ。数字 1 つ入力。
  Future<void> _editGoal(BuildContext context, {required int? current}) async {
    final controller = TextEditingController(
      text: current != null ? '$current' : '',
    );
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('月間の読書目標'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '例: 5',
            suffixText: '冊 / 月',
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0),
              child: const Text('目標をクリア'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(n);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final notifier = ref.read(readingGoalProvider.notifier);
    if (result == 0) {
      await notifier.setGoal(null);
    } else if (result > 0) {
      await notifier.setGoal(result);
    }
  }

  /// 本のリスト（リマインダー）を横スクロールで表示するセクション。
  Widget _bookListSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    required List<Book> books,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, icon, subtitle: subtitle, count: books.length),
        SizedBox(
          height: 230,
          child: AnimationLimiter(
            key: ValueKey('reminder-$title-${books.length}'),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 420),
                  child: SlideAnimation(
                    horizontalOffset: 32,
                    child: FadeInAnimation(
                      child: _homeBookCard(book, () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => BookDetail(book: book)),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  /// 本棚と同じ縦カード意匠のコンパクト版（表紙 + タイトル + 著者のみ）。
  Widget _homeBookCard(Book book, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 145,
        child: BookListItem(
          book: book,
          onPressed: onTap,
          compact: true,
          showActionButton: false,
          showRating: false,
          showStatusBadge: false,
        ),
      ),
    );
  }

  /// 楽天 API のおすすめセクション（横スクロール、Completer 連動）。
  Widget _recommendationSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String futureKey,
    String? subtitle,
  }) {
    final future = _recommendationFutures[futureKey];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, icon, subtitle: subtitle),
        SizedBox(
          height: 230,
          child: future == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<RankingItem>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data ?? const <RankingItem>[];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          '見つかりませんでした',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }
                    final shelfIds = ref
                        .watch(bookListProvider)
                        .map((b) => b.id)
                        .toSet();
                    return AnimationLimiter(
                      key: ValueKey('rec-$futureKey-${items.length}'),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final it = items[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 420),
                            child: SlideAnimation(
                              horizontalOffset: 32,
                              child: FadeInAnimation(
                                child: _recommendationCard(
                                  book: it.book,
                                  alreadyAdded: shelfIds.contains(it.book.id),
                                  onTap: () => showBookDetailSheet(
                                    context,
                                    ref: ref,
                                    book: it.book,
                                    api: _api,
                                    caption: it.caption,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  /// セクション見出し (小さい accent アイコン + セミボールドタイトル)。
  /// 副題はタイトル文字の下に muted で控えめに配置する。
  Widget _sectionHeader(String title, IconData icon,
      {String? subtitle, int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '($count)',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.mutedFg),
                ),
              ],
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

  Widget _recommendationCard({
    required Book book,
    required bool alreadyAdded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 145,
        child: Stack(
          children: [
            BookListItem(
              book: book,
              onPressed: onTap,
              compact: true,
              showActionButton: false,
              showRating: false,
              showStatusBadge: false,
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
                  child: const Icon(Icons.check,
                      size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// お気に入り著者 / ジャンルが変わったら新しい Completer を作って
  /// バックグラウンドで楽天 API を逐次叩く。
  void _scheduleRecommendationLoad(String? author, String? genreId) {
    // 既存 Completer はリセット（再ビルド時の連続実行を避ける）
    _recommendationCompleters.clear();
    final next = <String, Future<List<RankingItem>>>{};
    if (author != null) {
      final c = Completer<List<RankingItem>>();
      _recommendationCompleters['author:$author'] = c;
      next['author:$author'] = c.future;
    }
    if (genreId != null) {
      final c = Completer<List<RankingItem>>();
      _recommendationCompleters['genre:$genreId'] = c;
      next['genre:$genreId'] = c.future;
    }
    setState(() {
      _recommendationFutures = next;
    });

    // 非同期に逐次取得開始（レート制限 1 req/sec 対策で 1.1s 間隔）。
    () async {
      if (author != null) {
        try {
          final r = await _api.searchByAuthor(author: author);
          _completeIfActive('author:$author', r);
        } catch (e) {
          _completeIfActive('author:$author', const []);
        }
        if (genreId != null) {
          await Future.delayed(const Duration(milliseconds: 1100));
        }
      }
      if (genreId != null) {
        try {
          final r = await _api.searchRanking(booksGenreId: genreId);
          _completeIfActive('genre:$genreId', r);
        } catch (e) {
          _completeIfActive('genre:$genreId', const []);
        }
      }
    }();
  }

  void _completeIfActive(String key, List<RankingItem> items) {
    final c = _recommendationCompleters[key];
    if (c != null && !c.isCompleted) {
      c.complete(items);
    }
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}
