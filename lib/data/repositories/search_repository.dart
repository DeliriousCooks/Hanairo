import 'dart:async';
import '../../domain/entities/post.dart';
import '../datasources/booru_api.dart';
import '../../core/utils/logger.dart';

class SearchRepository {
  final Map<BooruSource, BooruDataSource> _sources;

  SearchRepository()
      : _sources = {
          BooruSource.rule34xxx: Rule34xxxDataSource(),
          BooruSource.e621: E621DataSource(),
          BooruSource.gelbooru: GelbooruDataSource(),
          BooruSource.paheal: PahealDataSource(),
        };

  BooruDataSource sourceFor(BooruSource source) => _sources[source]!;

  /// Search multiple sources concurrently and merge results
  Future<List<Post>> search(SearchQuery query) async {
    final futures = query.sources.map((source) async {
      final ds = _sources[source];
      if (ds == null) return <Post>[];
      try {
        return await ds.search(query).timeout(const Duration(seconds: 25));
      } catch (e) {
        AppLogger.error('Source $source timed out or failed', e);
        return <Post>[];
      }
    });

    final results = await Future.wait(futures);
    final merged = results.expand((r) => r).toList();

    // Sort by score descending when merging multiple sources
    if (query.sources.length > 1) {
      merged.sort((a, b) => b.score.compareTo(a.score));
    }

    return merged;
  }

  /// Get tag suggestions from all active sources
  Future<List<String>> getTagSuggestions(
    String prefix,
    List<BooruSource> sources,
  ) async {
    if (prefix.length < 2) return [];

    final futures = sources.map((source) {
      final ds = _sources[source];
      if (ds == null) return Future.value(<String>[]);
      return ds.getTagSuggestions(prefix).catchError((_) => <String>[]);
    });

    final results = await Future.wait(futures);
    final seen = <String>{};
    final merged = <String>[];

    for (final list in results) {
      for (final tag in list) {
        if (seen.add(tag)) {
          merged.add(tag);
        }
      }
    }

    return merged.take(30).toList();
  }

  Future<bool> login(BooruSource source, String username, String credential) {
    final ds = _sources[source];
    if (ds == null) return Future.value(false);
    return ds.login(username, credential);
  }

  Future<bool> addFavorite(BooruSource source, String postId) {
    final ds = _sources[source];
    if (ds == null) return Future.value(false);
    return ds.addFavorite(postId);
  }

  Future<bool> removeFavorite(BooruSource source, String postId) {
    final ds = _sources[source];
    if (ds == null) return Future.value(false);
    return ds.removeFavorite(postId);
  }
}
