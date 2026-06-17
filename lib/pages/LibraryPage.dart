/// ライブラリタブ（W12 で新規追加）。
///
/// Apple Music の Library 風に「自分でまとめた分類」を集約する場所。
/// W11 で実装した♡お気に入り本のセクションと、W12 のタグ機能を統合する。
///
/// セクション構成:
///   1. お気に入りの本（横スクロールカード、本詳細に遷移）
///   2. タグ一覧（タップで TagBooksPage に遷移、そのタグの本一覧）
///   3. 「+ 新規タグ作成」「⚙️ タグ管理」アクション
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../detail/BookDetail.dart';
import '../models/book.dart';
import '../providers/book_list_provider.dart';
import '../providers/custom_tags_provider.dart';
import '../services/tag_calculator.dart';
import 'TagBooksPage.dart';
import 'TagManagementPage.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(bookListProvider);
    final favorites = books.where((b) => b.isFavorite).toList();
    final usedTags = collectAllTags(books);
    final customTags = ref.watch(customTagsProvider);

    // 本に紐付くタグ + 0 冊の定義済みタグをマージ。
    // 冊数の多い順 → 同点はタグ名昇順で安定化（0 冊タグは末尾）。
    final usedTagsByName = {for (final t in usedTags) t.name: t.count};
    final allTagNames = <String>{...usedTagsByName.keys, ...customTags};
    final tags = allTagNames
        .map((name) =>
            TagCount(name: name, count: usedTagsByName[name] ?? 0))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('ライブラリ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'タグを管理',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagManagementPage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          _favoritesSection(context, favorites),
          const Divider(height: 24),
          _tagsSection(context, tags),
          if (favorites.isEmpty && tags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '本詳細から♥ボタンを押す、もしくはタグを付けると、ここに集約されます',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _favoritesSection(BuildContext context, List<Book> favorites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.favorite, size: 18, color: Colors.pink),
              const SizedBox(width: 6),
              const Text(
                'お気に入りの本',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (favorites.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('(${favorites.length})',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
        if (favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'まだお気に入りに登録された本はありません',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final b = favorites[index];
                return _favoriteCard(context, b);
              },
            ),
          ),
      ],
    );
  }

  Widget _tagsSection(BuildContext context, List<TagCount> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined, size: 18),
              const SizedBox(width: 6),
              const Text(
                'タグ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('(${tags.length})',
                    style: const TextStyle(color: Colors.black54)),
              ],
            ],
          ),
        ),
        if (tags.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'まだタグがありません。本詳細の「+ タグを追加」から付けられます',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          )
        else
          ...tags.map((t) => ListTile(
                leading: const Icon(Icons.tag, size: 20),
                title: Text(t.name),
                subtitle: Text(
                  t.count > 0 ? '${t.count} 冊' : '0 冊（まだ本に付いていません）',
                  style: TextStyle(
                    color: t.count > 0 ? null : Colors.black45,
                  ),
                ),
                trailing: t.count > 0
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: t.count > 0
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TagBooksPage(tag: t.name),
                          ),
                        );
                      }
                    : null,
              )),
      ],
    );
  }

  Widget _favoriteCard(BuildContext context, Book book) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetail(book: book)),
        );
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(book),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Book book) {
    final url = book.coverImageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: 110,
        height: 145,
        color: Colors.grey.shade300,
        child: const Center(
          child: Icon(Icons.book, size: 40, color: Colors.black54),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: 110,
      height: 145,
      fit: BoxFit.cover,
      placeholder: (c, _) => Container(
        width: 110,
        height: 145,
        color: Colors.grey.shade100,
      ),
      errorWidget: (c, _, __) => Container(
        width: 110,
        height: 145,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}
