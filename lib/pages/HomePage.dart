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
import '../detail/BookDetail.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../providers/reading_goal_provider.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム'),
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
            ),
          if (topGenreId != null)
            _recommendationSection(
              context,
              title: 'よく読むジャンルの売れ筋',
              icon: Icons.auto_awesome,
              futureKey: 'genre:$topGenreId',
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 18),
                const SizedBox(width: 6),
                const Text('今月の読書目標',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => _editGoal(context, current: goal),
                  child: Text(goal == null ? '目標を設定' : '変更'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (goal == null)
              const Text(
                'まだ目標が設定されていません',
                style: TextStyle(color: Colors.black54),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$thisMonth',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '/ $goal 冊（${(pct * 100).round()}%）',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ],
        ),
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
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _bookCard(book, () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BookDetail(book: book)),
                );
              });
            },
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  /// 楽天 API のおすすめセクション（横スクロール、Completer 連動）。
  Widget _recommendationSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String futureKey,
  }) {
    final future = _recommendationFutures[futureKey];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title, icon),
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
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];
                        return _recommendationCard(
                          book: it.book,
                          alreadyAdded: shelfIds.contains(it.book.id),
                          onTap: () => showBookDetailSheet(
                            context,
                            ref: ref,
                            book: it.book,
                            api: _api,
                            caption: it.caption,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon,
      {String? subtitle, int? count}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.black54),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('($count)',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  Widget _bookCard(Book book, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(book, width: 110, height: 145),
            const SizedBox(height: 6),
            Text(book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text(book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard({
    required Book book,
    required bool alreadyAdded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _cover(book, width: 120, height: 160),
                if (alreadyAdded)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
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
            const SizedBox(height: 6),
            Text(book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text(book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _cover(Book book, {required double width, required double height}) {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book_outlined, size: 40, color: Colors.black54),
        ),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (c, _, __) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
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
