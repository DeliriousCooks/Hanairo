import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/post.dart';
import '../../blocs/search_bloc.dart';
import '../../widgets/grid/post_grid.dart';
import '../../widgets/search/search_bar_widget.dart';
import '../../widgets/search/filter_sheet.dart';
import '../../widgets/common/source_badge.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _searchController;
  final _scrollController = ScrollController();
  bool _showSuggestions = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitSearch(widget.initialQuery);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final state = context.read<SearchBloc>().state;
      if (state.status == SearchStatus.success && state.hasMore) {
        context.read<SearchBloc>().add(SearchLoadMore());
      }
    }
  }

  void _submitSearch(String query) {
    setState(() => _showSuggestions = false);
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final bloc = context.read<SearchBloc>();
    bloc.add(SearchSubmitted(query, bloc.state.activeSources));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── Main Content ──────────────────────────────────────────────────
          BlocBuilder<SearchBloc, SearchState>(
            builder: (context, state) {
              return CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Header space for search bar
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 72,
                    ),
                  ),

                  // Source chips
                  SliverToBoxAdapter(
                    child: _SourceFilter(state: state),
                  ),

                  // Results count / status
                  if (state.status == SearchStatus.success ||
                      state.status == SearchStatus.loadingMore)
                    SliverToBoxAdapter(
                      child: _ResultsHeader(state: state),
                    ),

                  // Grid or placeholder
                  if (state.status == SearchStatus.initial)
                    const SliverFillRemaining(
                      child: _EmptyState(),
                    )
                  else if (state.status == SearchStatus.loading)
                    const SliverToBoxAdapter(child: _LoadingGrid())
                  else if (state.status == SearchStatus.failure)
                    SliverFillRemaining(
                      child: _ErrorState(
                        message: state.errorMessage ?? 'Something went wrong',
                        onRetry: () => context
                            .read<SearchBloc>()
                            .add(SearchRefreshed()),
                      ),
                    )
                  else if (state.posts.isEmpty &&
                      state.status == SearchStatus.success)
                    const SliverFillRemaining(child: _NoResultsState())
                  else ...[
                    PostGridSliver(
                      posts: state.posts,
                      onPostTapped: (post, index) {
                        context.go('/viewer', extra: {
                          'posts': state.posts,
                          'index': index,
                        });
                      },
                    ),
                    if (state.status == SearchStatus.loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),

          // ─── Floating Search Bar ───────────────────────────────────────────
          _FloatingSearchBar(
            controller: _searchController,
            onChanged: (q) {
              context.read<SearchBloc>().add(SearchQueryChanged(q));
              setState(() => _showSuggestions = q.isNotEmpty);
            },
            onSubmitted: _submitSearch,
            onFilterTapped: () => _showFilterSheet(context),
            showSuggestions: _showSuggestions,
            onSuggestionSelected: (tag) {
              final current = _searchController.text.trim();
              final parts = current.split(' ');
              if (parts.isNotEmpty) parts.removeLast();
              parts.add(tag);
              final newQuery = '${parts.join(' ')} ';
              _searchController.text = newQuery;
              _searchController.selection = TextSelection.fromPosition(
                TextPosition(offset: newQuery.length),
              );
              context.read<SearchBloc>().add(SearchQueryChanged(newQuery));
            },
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: context.read<SearchBloc>(),
        child: const FilterSheet(),
      ),
    );
  }
}

// ─── Floating Search Bar ───────────────────────────────────────────────────────

class _FloatingSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTapped;
  final bool showSuggestions;
  final ValueChanged<String> onSuggestionSelected;

  const _FloatingSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onFilterTapped,
    required this.showSuggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Blur background
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.92),
              border: Border(
                bottom: showSuggestions
                    ? BorderSide.none
                    : BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                        width: 0.5,
                      ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SearchBarWidget(
                      controller: controller,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(onTap: onFilterTapped),
                ],
              ),
            ),
          ),

          // Suggestions dropdown
          if (showSuggestions)
            BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (p, c) => p.tagSuggestions != c.tagSuggestions,
              builder: (context, state) {
                if (state.tagSuggestions.isEmpty) return const SizedBox();
                return _SuggestionsDropdown(
                  suggestions: state.tagSuggestions,
                  onSelected: onSuggestionSelected,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FilterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) =>
          p.ratingFilter != c.ratingFilter ||
          p.minScore != c.minScore ||
          p.fileTypeFilter != c.fileTypeFilter,
      builder: (context, state) {
        final hasFilters = state.ratingFilter != null ||
            state.minScore != null ||
            (state.fileTypeFilter?.isNotEmpty ?? false);

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasFilters
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFilters
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : theme.colorScheme.outline.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: hasFilters
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (hasFilters)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionsDropdown extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  const _SuggestionsDropdown({
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final tag = suggestions[index];
          return InkWell(
            onTap: () => onSelected(tag),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.tag_rounded,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tag.replaceAll('_', ' '),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SourceFilter extends StatelessWidget {
  final SearchState state;
  const _SourceFilter({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: BooruSource.values.take(4).map((source) {
          final isActive = state.activeSources.contains(source);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(source.shortName),
              selected: isActive,
              onSelected: (_) {
                HapticFeedback.selectionClick();
                context.read<SearchBloc>().add(SearchSourceToggled(source));
              },
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  final SearchState state;
  const _ResultsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            '${state.posts.length} results',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (state.tagString.isNotEmpty)
            Text(
              '"${state.tagString}"',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.image_search_rounded,
                size: 40,
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Search for content',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter tags above to search across\nyour selected sources',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    return Shimmer.fromColors(
      baseColor: ext?.shimmerBase ?? AppColors.darkCard,
      highlightColor: ext?.shimmerHighlight ?? AppColors.darkCardElevated,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.8,
        ),
        itemCount: 18,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text('No results found', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Try different tags or change\nyour active sources',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
