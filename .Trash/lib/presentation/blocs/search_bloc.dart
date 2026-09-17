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
  final List<BooruSource> activeSources;
  final ContentRating? ratingFilter;
  final int? minScore;
  final List<FileType>? fileTypeFilter;
  final int currentPage;
  final bool hasMore;
  final String? errorMessage;
  final List<String> tagSuggestions;

  const SearchState({
    this.status = SearchStatus.initial,
    this.posts = const [],
    this.tagString = '',
    this.activeSources = const [BooruSource.rule34xxx, BooruSource.e621],
    this.ratingFilter,
    this.minScore,
    this.fileTypeFilter,
    this.currentPage = 0,
    this.hasMore = true,
    this.errorMessage,
    this.tagSuggestions = const [],
  });

  SearchState copyWith({
    SearchStatus? status,
    List<Post>? posts,
    String? tagString,
    List<BooruSource>? activeSources,
    ContentRating? ratingFilter,
    bool clearRatingFilter = false,
    int? minScore,
    bool clearMinScore = false,
    List<FileType>? fileTypeFilter,
    bool clearFileTypeFilter = false,
    int? currentPage,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    List<String>? tagSuggestions,
  }) {
    return SearchState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      tagString: tagString ?? this.tagString,
      activeSources: activeSources ?? this.activeSources,
      ratingFilter: clearRatingFilter ? null : (ratingFilter ?? this.ratingFilter),
      minScore: clearMinScore ? null : (minScore ?? this.minScore),
      fileTypeFilter: clearFileTypeFilter ? null : (fileTypeFilter ?? this.fileTypeFilter),
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      tagSuggestions: tagSuggestions ?? this.tagSuggestions,
    );
  }

  SearchQuery get currentQuery => SearchQuery(
        tags: tagString.trim().isEmpty
            ? []
            : tagString.trim().split(RegExp(r'\s+')),
        sources: activeSources,
        ratingFilter: ratingFilter,
        minScore: minScore,
        fileTypeFilter: fileTypeFilter,
        page: currentPage,
        limit: 40,
      );

  @override
  List<Object?> get props => [
        status,
        posts,
        tagString,
        activeSources,
        ratingFilter,
        minScore,
        fileTypeFilter,
        currentPage,
        hasMore,
        errorMessage,
        tagSuggestions,
      ];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _searchRepo;
  final LocalRepository _localRepo;
  Timer? _suggestionTimer;

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
    on<SearchSubmitted>(_onSearchSubmitted);
    on<SearchLoadMore>(_onSearchLoadMore);
    on<SearchRefreshed>(_onSearchRefreshed);
    on<SearchQueryChanged>(_onQueryChanged,
        transformer: (events, mapper) =>
            events.debounceTime(const Duration(milliseconds: 300)).switchMap(mapper));
    on<SearchSourceToggled>(_onSourceToggled);
    on<SearchFilterChanged>(_onFilterChanged);
    on<PostFavoriteToggled>(_onFavoriteToggled);
  }

  Future<void> _onSearchSubmitted(
    SearchSubmitted event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(
      status: SearchStatus.loading,
      tagString: event.tagString,
      activeSources: event.sources,
      posts: [],
      currentPage: 0,
      hasMore: true,
      clearError: true,
      tagSuggestions: [],
    ));

    // Save to history
    if (event.tagString.trim().isNotEmpty) {
      await _localRepo.addSearchHistory(event.tagString.trim());
    }

    try {
      final query = state.currentQuery;
      final posts = await _searchRepo.search(query);
      final filtered = _applyBlacklist(posts);

      emit(state.copyWith(
        status: SearchStatus.success,
        posts: filtered,
        hasMore: posts.length >= query.limit,
      ));
    } catch (e) {
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

    emit(state.copyWith(status: SearchStatus.loadingMore));

    try {
      final nextPage = state.currentPage + 1;
      final query = state.currentQuery.copyWith(page: nextPage);
      final posts = await _searchRepo.search(query);
      final filtered = _applyBlacklist(posts);

      emit(state.copyWith(
        status: SearchStatus.success,
        posts: [...state.posts, ...filtered],
        currentPage: nextPage,
        hasMore: posts.length >= query.limit,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: 'Failed to load more posts.',
      ));
    }
  }

  Future<void> _onSearchRefreshed(
    SearchRefreshed event,
    Emitter<SearchState> emit,
  ) async {
    if (state.tagString.isEmpty) return;
    add(SearchSubmitted(state.tagString, state.activeSources));
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query;
    emit(state.copyWith(tagString: query));

    if (query.isEmpty || query.endsWith(' ')) {
      emit(state.copyWith(tagSuggestions: []));
      return;
    }

    final lastTag = query.trim().split(' ').last;
    if (lastTag.length < 2) {
      emit(state.copyWith(tagSuggestions: []));
      return;
    }

    try {
      final suggestions = await _searchRepo.getTagSuggestions(
        lastTag,
        state.activeSources,
      );
      emit(state.copyWith(tagSuggestions: suggestions));
    } catch (e) {
      emit(state.copyWith(tagSuggestions: []));
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
  }

  void _onFilterChanged(
    SearchFilterChanged event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(
      ratingFilter: event.ratingFilter,
      minScore: event.minScore,
      fileTypeFilter: event.fileTypeFilter,
    ));
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

  @override
  Future<void> close() {
    _suggestionTimer?.cancel();
    return super.close();
  }
}
