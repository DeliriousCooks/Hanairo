import 'dart:async';
import '../../domain/entities/post.dart';
import '../datasources/booru_api.dart';
import '../../core/utils/logger.dart';
import '../../core/tags/tag_translator.dart';

class SourceResult {
  final List<Post> posts;
  final bool failed;
  final String? errorMessage;
  const SourceResult(this.posts, {this.failed = false, this.errorMessage});
}

class SearchRepository {
  final Map<BooruSource, BooruDataSource> _sources;
  final Map<String, ({DateTime at, List<String> tags})> _suggestionCache = {};
  final Map<String, ({DateTime at, int count})> _tagCountCache = {};

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
        return MapEntry(
          source,
          SourceResult([], failed: true, errorMessage: e.toString()),
        );
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

    final normalized = prefix.trim().toLowerCase();
    final seen = <String>{};
    final merged = <String>[];

    // Return cached suggestions immediately when possible. Cache keys include
    // the enabled source set so switching sources never leaks stale results.
    for (final source in sources) {
      final key = '${source.name}|$normalized';
      final cached = _suggestionCache[key];
      if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
        for (final tag in cached.tags) {
          if (seen.add(tag)) merged.add(tag);
        }
      }
    }

    // A cache hit is fast enough to use immediately. For misses, fetch all
    // sources concurrently; the BLoC also emits each source as it completes.
    if (merged.length >= 10) return merged.take(30).toList();

    final futures = sources.map((source) async {
      final ds = _sources[source];
      if (ds == null) return <String>[];
      final key = '${source.name}|$normalized';
      final cached = _suggestionCache[key];
      if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
        return cached.tags;
      }
      final list = await ds.getTagSuggestions(normalized).catchError((_) => <String>[]);
      _suggestionCache[key] = (at: DateTime.now(), tags: list);
      return list;
    });

    final results = await Future.wait(futures);
    for (final list in results) {
      for (final tag in list) {
        if (seen.add(tag)) merged.add(tag);
      }
    }
    return merged.take(30).toList();
  }

  /// Fetches each selected site's count for one exact tag. Counts are omitted
  /// when a site does not return an exact match or its tag endpoint is down.
  Future<Map<BooruSource, int>> getTagCounts(
    String tag,
    List<BooruSource> sources,
  ) async {
    final results = await Future.wait(sources.map((source) async {
      final translated = TagTranslator.translate([tag], source);
      if (translated.isEmpty) return null;
      final count = await _sources[source]
          ?.getTagCount(translated.single)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      return count == null ? null : MapEntry(source, count);
    }));
    return Map.fromEntries(results.whereType<MapEntry<BooruSource, int>>());
  }

  /// Counts each requested tag on every enabled source. These are independent
  /// tag totals (not the intersection count for a multi-tag search).
  Future<Map<BooruSource, Map<String, int>>> getTagCountsForTags(
    List<String> tags,
    List<BooruSource> sources,
  ) async {
    final cleanTags = tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList();
    if (cleanTags.isEmpty || sources.isEmpty) return {};

    final entries = await Future.wait(sources.map((source) async {
      final counts = <String, int>{};
      await Future.wait(cleanTags.map((tag) async {
        final translated = TagTranslator.translate([tag], source);
        if (translated.isEmpty) return;
        final canonical = translated.single;
        final key = '${source.name}|$canonical';
        final cached = _tagCountCache[key];
        if (cached != null && DateTime.now().difference(cached.at) < const Duration(minutes: 10)) {
          counts[tag] = cached.count;
          return;
        }
        final count = await _sources[source]
            ?.getTagCount(canonical)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (count != null) {
          _tagCountCache[key] = (at: DateTime.now(), count: count);
          counts[tag] = count;
        }
      }));
      return MapEntry(source, counts);
    }));

    return Map.fromEntries(entries);
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
