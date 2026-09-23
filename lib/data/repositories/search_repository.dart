import 'dart:async';
import '../../domain/entities/post.dart';
import '../datasources/booru_api.dart';
import '../../core/utils/logger.dart';

class SourceResult {
  final List<Post> posts;
  final bool failed;
  const SourceResult(this.posts, {this.failed = false});
}

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

  /// Search multiple sources concurrently, keeping each source's results
  /// separate. Callers that need pagination should use this instead of
  /// [search], since merging all sources into one flat list makes it
  /// impossible to tell which individual sources still have more pages.
  Future<Map<BooruSource, List<Post>>> searchPerSource(SearchQuery query) async {
    final full = await searchPerSourceDetailed(query);
    return full.map((source, result) => MapEntry(source, result.posts));
  }

  /// Like [searchPerSource], but distinguishes "a source genuinely returned
  /// zero matches" from "a source's request failed" (network error, auth
  /// error, rate limit, etc). Callers that want to surface real errors to
  /// the user - instead of silently showing them as "0 results" - should
  /// use this.
  Future<Map<BooruSource, SourceResult>> searchPerSourceDetailed(SearchQuery query) async {
    final entries = await Future.wait(query.sources.map((source) async {
      final ds = _sources[source];
      if (ds == null) return MapEntry(source, const SourceResult([]));
      try {
        final posts = await ds.search(query).timeout(const Duration(seconds: 25));
        return MapEntry(source, SourceResult(posts));
      } catch (e) {
        AppLogger.error('Source $source timed out or failed', e);
        return MapEntry(source, const SourceResult([], failed: true));
      }
    }));
    return Map.fromEntries(entries);
  }

  /// Search multiple sources concurrently and merge results into one
  /// flat, score-sorted list. Convenient for one-shot searches, but does
  /// not carry enough information to paginate correctly across sources -
  /// use [searchPerSource] for that.
  Future<List<Post>> search(SearchQuery query) async {
    final perSource = await searchPerSource(query);
    final merged = perSource.values.expand((r) => r).toList();

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
