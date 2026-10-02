import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/post.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/local_repository.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class SearchEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SearchSubmitted extends SearchEvent {
  final String tagString;
  final List<BooruSource> sources;
  SearchSubmitted(this.tagString, this.sources);
  @override
  List<Object?> get props => [tagString, sources];
}

class SearchLoadMore extends SearchEvent {}

class SearchRefreshed extends SearchEvent {}

class SearchQueryChanged extends SearchEvent {
  final String query;
  SearchQueryChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class SearchCleared extends SearchEvent {}

class SearchSourceToggled extends SearchEvent {
  final BooruSource source;
  SearchSourceToggled(this.source);
  @override
  List<Object?> get props => [source];
}

class SearchFilterChanged extends SearchEvent {
  final ContentRating? ratingFilter;
  final int? minScore;
  final List<FileType>? fileTypeFilter;
  SearchFilterChanged({this.ratingFilter, this.minScore, this.fileTypeFilter});
  @override
  List<Object?> get props => [ratingFilter, minScore, fileTypeFilter];
}

class PostFavoriteToggled extends SearchEvent {
  final Post post;
  PostFavoriteToggled(this.post);
  @override
  List<Object?> get props => [post.uniqueId];
}

// ─── State ────────────────────────────────────────────────────────────────────

enum SearchStatus { initial, loading, success, failure, loadingMore }

class SearchState extends Equatable {
  final SearchStatus status;
  final List<Post> posts;
  final String tagString;
  final String suggestionQuery;
  final List<BooruSource> activeSources;
  final ContentRating? ratingFilter;
  final int? minScore;
  final List<FileType>? fileTypeFilter;
  final Map<BooruSource, int> pageBySource;
  final Map<BooruSource, bool> hasMoreBySource;
  final List<BooruSource> failedSources;
  final Map<BooruSource, String> sourceErrors;
  final String? errorMessage;
  final List<String> tagSuggestions;
  final Map<String, int> tagSuggestionCounts;
  final Map<BooruSource, Map<String, int>> tagCountsBySource;

  const SearchState({
    this.status = SearchStatus.initial,
    this.posts = const [],
    this.tagString = '',
    this.suggestionQuery = '',
    this.activeSources = const [BooruSource.rule34xxx, BooruSource.e621],
    this.ratingFilter,
    this.minScore,
    this.fileTypeFilter,
    this.pageBySource = const {},
    this.hasMoreBySource = const {},
    this.failedSources = const [],
    this.sourceErrors = const {},
    this.errorMessage,
    this.tagSuggestions = const [],
    this.tagSuggestionCounts = const {},
    this.tagCountsBySource = const {},
  });

  /// True if at least one active source might still have more results to
  /// paginate into. Tracking this per-source (rather than one flat flag
  /// derived from the total merged post count) matters because sources
  /// exhaust at different points - a source with fewer matches, or one
  /// that's temporarily returning nothing, shouldn't stop pagination for
  /// sources that still have plenty more.
  bool get hasMore => hasMoreBySource.values.any((v) => v);

  SearchState copyWith({
    SearchStatus? status,
    List<Post>? posts,
    String? tagString,
    String? suggestionQuery,
    List<BooruSource>? activeSources,
    ContentRating? ratingFilter,
    bool clearRatingFilter = false,
    int? minScore,
    bool clearMinScore = false,
    List<FileType>? fileTypeFilter,
    bool clearFileTypeFilter = false,
    Map<BooruSource, int>? pageBySource,
    Map<BooruSource, bool>? hasMoreBySource,
    List<BooruSource>? failedSources,
    Map<BooruSource, String>? sourceErrors,
    String? errorMessage,
    bool clearError = false,
    List<String>? tagSuggestions,
    Map<String, int>? tagSuggestionCounts,
    bool clearTagSuggestionCounts = false,
    Map<BooruSource, Map<String, int>>? tagCountsBySource,
    bool clearTagCounts = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      tagString: tagString ?? this.tagString,
      suggestionQuery: suggestionQuery ?? this.suggestionQuery,
      activeSources: activeSources ?? this.activeSources,
      ratingFilter: clearRatingFilter ? null : (ratingFilter ?? this.ratingFilter),
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      fileTypeFilter: clearFileTypeFilter ? null : (fileTypeFilter ?? this.fileTypeFilter),
      pageBySource: pageBySource ?? this.pageBySource,
      hasMoreBySource: hasMoreBySource ?? this.hasMoreBySource,
      failedSources: failedSources ?? this.failedSources,
      sourceErrors: sourceErrors ?? this.sourceErrors,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tagSuggestions: tagSuggestions ?? this.tagSuggestions,
      tagSuggestionCounts: clearTagSuggestionCounts
          ? const {}
          : (tagSuggestionCounts ?? this.tagSuggestionCounts),
      tagCountsBySource: clearTagCounts ? const {} : (tagCountsBySource ?? this.tagCountsBySource),
    );
  }

  /// Query used for the *initial* search (page 0, across every active
  /// source). Loading additional pages afterward is handled per-source in
  /// the bloc, since each source paginates independently.
  SearchQuery get currentQuery => SearchQuery(
        tags: tagString.trim().isEmpty
            ? []
            : tagString.trim().split(RegExp(r'\s+')),
        sources: activeSources,
        ratingFilter: ratingFilter,
        minScore: minScore,
        fileTypeFilter: fileTypeFilter,
        page: 0,
        limit: 60,
      );

  @override
  List<Object?> get props => [
        status,
        posts,
        tagString,
        suggestionQuery,
        activeSources,
        ratingFilter,
        minScore,
        fileTypeFilter,
        pageBySource,
        hasMoreBySource,
        failedSources,
        sourceErrors,
        errorMessage,
        tagSuggestions,
        tagSuggestionCounts,
        tagCountsBySource,
      ];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _searchRepo;
  final LocalRepository _localRepo;
  Timer? _suggestionTimer;
  int _searchGeneration = 0;
  // A small look-ahead cache keeps the next pages ready without hammering
  // providers. It stores API metadata/posts, not the media files themselves.
  final Map<String, List<Post>> _prefetchedPages = {};
  final Set<String> _prefetchInFlight = {};

  SearchBloc({
    required SearchRepository searchRepo,
    required LocalRepository localRepo,
  })  : _searchRepo = searchRepo,
        _localRepo = localRepo,
        super(SearchState(
          activeSources: localRepo
              .getActiveSources()
              .map((s) => BooruSource.values.firstWhere((b) => b.name == s))
              .toList(),
        )) {
    // switchMap: if the user fires a new search before the previous one
    // finishes, the previous in-flight search is cancelled instead of
    // being allowed to land later and overwrite newer results. Same
    // pattern already used below for SearchQueryChanged.
    on<SearchSubmitted>(_onSearchSubmitted,
        transformer: (events, mapper) => events.switchMap(mapper));
    // exhaustMap (droppable): while a load-more is already in flight,
    // additional load-more events (e.g. rapid scroll-triggered calls)
    // are dropped instead of racing each other and double-appending pages.
    on<SearchLoadMore>(_onSearchLoadMore,
        transformer: (events, mapper) => events.exhaustMap(mapper));
    on<SearchRefreshed>(_onSearchRefreshed);
    on<SearchQueryChanged>(_onQueryChanged,
        transformer: (events, mapper) =>
            events.debounceTime(const Duration(milliseconds: 300)).switchMap(mapper));
    on<SearchCleared>(_onSearchCleared);
    on<SearchSourceToggled>(_onSourceToggled);
    on<SearchFilterChanged>(_onFilterChanged);
    on<PostFavoriteToggled>(_onFavoriteToggled);
  }

  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    final requestGeneration = ++_searchGeneration;
    _prefetchedPages.clear();
    _prefetchInFlight.clear();
    emit(state.copyWith(
      status: SearchStatus.loading,
      tagString: event.tagString,
      suggestionQuery: '',
      activeSources: event.sources,
      posts: [],
      pageBySource: {for (final s in event.sources) s: 0},
      hasMoreBySource: {for (final s in event.sources) s: true},
      failedSources: const [],
      sourceErrors: const {},
      clearError: true,
      tagSuggestions: [],
      clearTagSuggestionCounts: true,
      clearTagCounts: true,
    ));

    final query = state.currentQuery;
    try {
      if (event.tagString.trim().isNotEmpty) {
        await _localRepo.addSearchHistory(event.tagString.trim());
      }
      if (emit.isDone || requestGeneration != _searchGeneration) return;

      final perSource = await _searchRepo.searchPerSourceDetailed(query);
      if (emit.isDone || requestGeneration != _searchGeneration) return;
      final merged = perSource.values.expand((r) => r.posts).toList();
      if (query.sources.length > 1) {
        merged.sort((a, b) => b.score.compareTo(a.score));
      }
      final deduped = _dedupeAgainst(const [], merged);
      final filtered = _applyBlacklist(deduped);
      final failed = perSource.entries.where((e) => e.value.failed).map((e) => e.key).toList();
      final sourceErrors = {
        for (final entry in perSource.entries)
          if (entry.value.errorMessage != null)
            entry.key: entry.value.errorMessage!,
      };

      emit(state.copyWith(
        status: SearchStatus.success,
        posts: filtered,
        // A source is only truly exhausted when it returns an empty page.
        // Treating "fewer than the requested limit" as end-of-results is
        // wrong for these APIs - a page can legitimately come back short
        // (moderation/deletion between calls, provider-side trimming)
        // without meaning there's nothing left to paginate into. This is
        // what was capping combined searches at ~79 results.
        hasMoreBySource: {
          for (final entry in perSource.entries) entry.key: entry.value.posts.isNotEmpty,
        },
        failedSources: failed,
        sourceErrors: sourceErrors,
      ));

      // Warm two pages ahead in the background. This is deliberately modest:
      // Rule34's terms ask clients not to hammer the API, and its public docs
      // document a 1000-post request cap rather than a guaranteed 60 req/s
      // allowance.
      unawaited(_prefetchPages(query, requestGeneration, pagesAhead: 2));

      final tagParts = query.tags;
      // Counts never block the first result set. They load in the background
      // and are cached by the repository for fast repeat searches.
      if (tagParts.isNotEmpty) {
        unawaited(() async {
          final counts = await _searchRepo.getTagCountsForTags(
            tagParts,
            query.sources,
          );
          if (!emit.isDone &&
              requestGeneration == _searchGeneration &&
              state.tagString == event.tagString) {
            emit(state.copyWith(tagCountsBySource: counts));
          }
        }());
      }
    } catch (e) {
      if (emit.isDone || requestGeneration != _searchGeneration) return;
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'Search failed. Check your connection.',
      ));
    }
  }

  Future<void> _onSearchLoadMore(
    SearchLoadMore event,
    Emitter<SearchState> emit,
  ) async {
    if (state.status == SearchStatus.loadingMore || !state.hasMore) return;

    final requestedGeneration = _searchGeneration;

    // Only fetch the next page from sources that haven't run out yet -
    // each source paginates on its own, independent page number.
    final sourcesToLoad = state.activeSources
        .where((s) => state.hasMoreBySource[s] ?? false)
        .toList();
    if (sourcesToLoad.isEmpty) return;

    emit(state.copyWith(status: SearchStatus.loadingMore));

    try {
      final baseQuery = state.currentQuery;
      final nextPageBySource = {
        for (final s in sourcesToLoad) s: (state.pageBySource[s] ?? 0) + 1,
      };

      final results = await Future.wait(sourcesToLoad.map((source) async {
        final page = nextPageBySource[source]!;
        final key = _prefetchKey(baseQuery, source, page);
        final cached = _prefetchedPages.remove(key);
        if (cached != null) return MapEntry(source, cached);

        final query = baseQuery.copyWith(
          sources: [source],
          page: page,
        );
        final posts = await _searchRepo.sourceFor(source).search(query);
        return MapEntry(source, posts);
      }));
      if (emit.isDone || requestedGeneration != _searchGeneration) return;

      final newPosts = results.expand((e) => e.value).toList();
      final deduped = _dedupeAgainst(state.posts, newPosts);
      final filtered = _applyBlacklist(deduped);

      final updatedPageBySource = {...state.pageBySource, ...nextPageBySource};
      final updatedHasMoreBySource = {...state.hasMoreBySource};
      for (final entry in results) {
        updatedHasMoreBySource[entry.key] = entry.value.isNotEmpty;
      }

      final combined = [...state.posts, ...filtered];
      if (state.activeSources.length > 1) {
        combined.sort((a, b) => b.score.compareTo(a.score));
      }

      emit(state.copyWith(
        status: SearchStatus.success,
        posts: combined,
        pageBySource: updatedPageBySource,
        hasMoreBySource: updatedHasMoreBySource,
      ));

      unawaited(_prefetchPages(baseQuery, requestedGeneration, pagesAhead: 2));
    } catch (e) {
      if (emit.isDone || requestedGeneration != _searchGeneration) return;
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'Failed to load more posts.',
      ));
    }
  }

  String _prefetchKey(SearchQuery query, BooruSource source, int page) =>
      '${source.name}|${page}|${query.tagString}|${query.ratingFilter}|${query.minScore}|${query.fileTypeFilter}';

  Future<void> _prefetchPages(
    SearchQuery baseQuery,
    int generation, {
    int pagesAhead = 2,
  }) async {
    if (generation != _searchGeneration) return;

    for (final source in baseQuery.sources) {
      for (var offset = 1; offset <= pagesAhead; offset++) {
        if (generation != _searchGeneration) return;
        final page = (state.pageBySource[source] ?? 0) + offset;
        final key = _prefetchKey(baseQuery, source, page);
        if (_prefetchedPages.containsKey(key) || _prefetchInFlight.contains(key)) continue;

        // Keep provider pressure low: fetch one background page at a time.
        _prefetchInFlight.add(key);
        try {
          final query = baseQuery.copyWith(sources: [source], page: page);
          final posts = await _searchRepo.sourceFor(source).search(query);
          if (generation == _searchGeneration) {
            _prefetchedPages[key] = posts;
          }
        } catch (_) {
          // Prefetch is an optimization. Normal pagination will retry.
        } finally {
          _prefetchInFlight.remove(key);
        }
      }
    }
  }

  Future<void> _onSearchRefreshed(
    SearchRefreshed event,
    Emitter<SearchState> emit,
  ) async {
    if (state.tagString.isEmpty) return;
    add(SearchSubmitted(state.tagString, state.activeSources));
  }

  void _onSearchCleared(SearchCleared event, Emitter<SearchState> emit) {
    _searchGeneration++;
    _prefetchedPages.clear();
    _prefetchInFlight.clear();
    // Keep the user's chosen sources and filters, but remove stale results so
    // clearing the query returns Search to its clean, empty state.
    emit(SearchState(
      activeSources: state.activeSources,
      ratingFilter: state.ratingFilter,
      minScore: state.minScore,
      fileTypeFilter: state.fileTypeFilter,
    ));
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query;
    emit(state.copyWith(
      suggestionQuery: query,
      tagSuggestions: const [],
      clearTagSuggestionCounts: true,
    ));

    if (query.isEmpty || query.endsWith(' ')) {
      emit(state.copyWith(
        tagSuggestions: [],
        clearTagSuggestionCounts: true,
      ));
      return;
    }

    final lastTag = query.trim().split(' ').last;
    if (lastTag.length < 2) {
      emit(state.copyWith(
        tagSuggestions: [],
        clearTagSuggestionCounts: true,
      ));
      return;
    }

    try {
      final suggestions = await _searchRepo.getTagSuggestions(
        lastTag,
        state.activeSources.length > 1
            ? state.activeSources.take(1).toList()
            : state.activeSources,
      );
      if (emit.isDone || state.suggestionQuery != query) return;
      emit(state.copyWith(
        tagSuggestions: suggestions.take(5).toList(),
        clearTagSuggestionCounts: true,
      ));

      // Do not fetch count endpoints while the user is typing. Those extra
      // requests were the main source of autocomplete lag. Counts for the
      // submitted search are loaded separately after the first results appear.
      if (!emit.isDone && state.suggestionQuery == query) {
        emit(state.copyWith(clearTagSuggestionCounts: true));
      }
    } catch (e) {
      if (!emit.isDone && state.suggestionQuery == query) {
        emit(state.copyWith(
          tagSuggestions: [],
          clearTagSuggestionCounts: true,
        ));
      }
    }
  }

  void _onSourceToggled(
    SearchSourceToggled event,
    Emitter<SearchState> emit,
  ) {
    final sources = List<BooruSource>.from(state.activeSources);
    if (sources.contains(event.source)) {
      if (sources.length > 1) sources.remove(event.source);
    } else {
      sources.add(event.source);
    }
    emit(state.copyWith(activeSources: sources));
    // Search chips are live filters: changing one should refresh an active
    // query immediately instead of leaving results from the old source set.
    if (state.tagString.trim().isNotEmpty) {
      add(SearchSubmitted(state.tagString, sources));
    }
  }

  void _onFilterChanged(
    SearchFilterChanged event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(
      ratingFilter: event.ratingFilter,
      clearRatingFilter: event.ratingFilter == null,
      minScore: event.minScore,
      clearMinScore: event.minScore == null,
      fileTypeFilter: event.fileTypeFilter,
      clearFileTypeFilter: event.fileTypeFilter == null,
    ));

    // Changing a filter must actually re-run the active search. Previously the
    // sheet only changed BLoC state, leaving the old result set on screen.
    if (state.tagString.trim().isNotEmpty) {
      add(SearchSubmitted(state.tagString, state.activeSources));
    }
  }

  Future<void> _onFavoriteToggled(
    PostFavoriteToggled event,
    Emitter<SearchState> emit,
  ) async {
    final post = event.post;
    final isFav = _localRepo.isFavorite(post.uniqueId);

    if (isFav) {
      await _localRepo.removeFavorite(post.uniqueId);
    } else {
      await _localRepo.addFavorite(post);
    }

    // Update post in list
    final updated = state.posts.map((p) {
      if (p.uniqueId == post.uniqueId) {
        return p.copyWith(isFavorited: !isFav);
      }
      return p;
    }).toList();

    emit(state.copyWith(posts: updated));
  }

  List<Post> _applyBlacklist(List<Post> posts) {
    return posts.where((p) => !_localRepo.isBlacklisted(p)).toList();
  }

  /// Stable identity for a post across sources/pages, used to drop
  /// duplicates. Combines source + id since two different sources can
  /// coincidentally use the same numeric post id.
  String _postKey(Post p) => '${p.source.name}_${p.id}';

  /// Removes posts already present in [existing] from [incoming], and also
  /// de-dupes within [incoming] itself. Needed because: (a) pagination can
  /// occasionally hand back an overlapping post across page boundaries,
  /// and (b) multiple active sources could in principle surface the same
  /// underlying post. Without this, duplicates would eat into the visible
  /// "slots" a user scrolls through without adding anything new.
  List<Post> _dedupeAgainst(List<Post> existing, List<Post> incoming) {
    final seen = existing.map(_postKey).toSet();
    final result = <Post>[];
    for (final post in incoming) {
      final key = _postKey(post);
      if (seen.add(key)) result.add(post);
    }
    return result;
  }

  @override
  Future<void> close() {
    _suggestionTimer?.cancel();
    _prefetchedPages.clear();
    _prefetchInFlight.clear();
    return super.close();
  }
}
