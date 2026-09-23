import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/post.dart';
import '../../blocs/search_bloc.dart';
import '../../widgets/grid/post_grid.dart';
import '../../widgets/search/filter_sheet.dart';
import '../../widgets/common/page_background.dart';
import '../../../data/repositories/local_repository.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  // Tag chips: list of individual tags the user has added
  final List<String> _tagChips = [];
  // Text currently typed in the input (the "next" tag being composed)
  String _inputText = '';
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  bool _showSuggestions = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery.isNotEmpty) {
      // Parse initial query into chips
      final parts = widget.initialQuery.trim().split(RegExp(r'\s+'));
      _tagChips.addAll(parts.where((p) => p.isNotEmpty));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _submitSearch();
      });
    }

    _inputController.addListener(() {
      final text = _inputController.text;
      if (_inputText != text) {
        setState(() => _inputText = text);
        if (text.isNotEmpty && !text.endsWith(' ')) {
          context.read<SearchBloc>().add(SearchQueryChanged(text));
          setState(() => _showSuggestions = true);
        } else {
          context.read<SearchBloc>().add(SearchQueryChanged(''));
          setState(() => _showSuggestions = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      final state = context.read<SearchBloc>().state;
      if (state.status == SearchStatus.success && state.hasMore) {
        context.read<SearchBloc>().add(SearchLoadMore());
      }
    }
  }

  void _addTag(String tag) {
    final cleaned = tag.trim().replaceAll(' ', '_');
    if (cleaned.isEmpty) return;
    if (!_tagChips.contains(cleaned)) {
      setState(() => _tagChips.add(cleaned));
    }
    _inputController.clear();
    setState(() {
      _inputText = '';
      _showSuggestions = false;
    });
    context.read<SearchBloc>().add(SearchQueryChanged(''));
    // Auto-search when a tag is confirmed
    _submitSearch();
  }

  void _removeTag(String tag) {
    setState(() => _tagChips.remove(tag));
    _submitSearch();
  }

  void _submitSearch() {
    // Combine chips + any partial input text
    final allTags = [..._tagChips];
    final partial = _inputController.text.trim();
    if (partial.isNotEmpty) {
      allTags.add(partial.replaceAll(' ', '_'));
    }
    final query = allTags.join(' ');

    setState(() => _showSuggestions = false);
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final bloc = context.read<SearchBloc>();
    bloc.add(SearchSubmitted(query, bloc.state.activeSources));
  }

  String get _fullQueryString {
    final all = [..._tagChips];
    if (_inputText.trim().isNotEmpty) all.add(_inputText.trim());
    return all.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final topPad = MediaQuery.of(context).padding.top;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ─── Main scrollable content ──────────────────────────────────
            BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                // Dynamic header height based on chip count
                final chipsRows = (_tagChips.length / 3).ceil();
                final headerHeight = topPad +
                    56 + // search bar height
                    (chipsRows > 0 ? (chipsRows * 32 + 8).toDouble() : 0) +
                    8;

                return CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  // Key so grid doesn't rebuild on every state change that
                  // isn't changing the post list
                  slivers: [
                    // Space for the floating search header
                    SliverToBoxAdapter(
                      child: SizedBox(height: headerHeight + 4),
                    ),

                    // Source filter chips
                    SliverToBoxAdapter(
                      child: _SourceChips(state: state),
                    ),

                    // Results header with real count
                    if (state.status == SearchStatus.success ||
                        state.status == SearchStatus.loadingMore)
                      SliverToBoxAdapter(
                        child: _ResultsHeader(state: state),
                      ),

                    // Content
                    if (state.status == SearchStatus.initial)
                      const SliverFillRemaining(child: _EmptyState())
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
                        // Stable key: only rebuild when posts list actually
                        // changes identity (prevents grid reflow on
                        // unrelated state updates like loadingMore status)
                        key: ValueKey(state.posts.length),
                        posts: state.posts,
                        columns:
                            context.read<LocalRepository>().getGridColumns(),
                        onPostTapped: (post, index) {
                          context.push('/viewer', extra: {
                            'posts': state.posts,
                            'index': index,
                          });
                        },
                      ),
                      if (state.status == SearchStatus.loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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

            // ─── Floating search header ───────────────────────────────────
            _FloatingSearchHeader(
              tagChips: _tagChips,
              inputController: _inputController,
              inputFocus: _inputFocus,
              showSuggestions: _showSuggestions,
              onTagRemoved: _removeTag,
              onTagAdded: _addTag,
              onSubmitted: (_) => _submitSearch(),
              onFilterTapped: () => _showFilterSheet(context),
              onSuggestionSelected: _addTag,
              onDismissSuggestions: () {
                setState(() => _showSuggestions = false);
              },
            ),
          ],
        ),
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

// ─── Floating Search Header with Tag Chips ─────────────────────────────────

class _FloatingSearchHeader extends StatelessWidget {
  final List<String> tagChips;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final bool showSuggestions;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTapped;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onDismissSuggestions;

  const _FloatingSearchHeader({
    required this.tagChips,
    required this.inputController,
    required this.inputFocus,
    required this.showSuggestions,
    required this.onTagRemoved,
    required this.onTagAdded,
    required this.onSubmitted,
    required this.onFilterTapped,
    required this.onSuggestionSelected,
    required this.onDismissSuggestions,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main search bar container
          Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.94),
              border: showSuggestions
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.12),
                        width: 0.5,
                      ),
                    ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, topPad + 10, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input row
                  Row(
                    children: [
                      Expanded(
                        child: _TagChipInput(
                          tagChips: tagChips,
                          inputController: inputController,
                          inputFocus: inputFocus,
                          onTagRemoved: onTagRemoved,
                          onTagAdded: onTagAdded,
                          onSubmitted: onSubmitted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _FilterButton(onTap: onFilterTapped),
                    ],
                  ),
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

// ─── Tag Chip Input ────────────────────────────────────────────────────────

class _TagChipInput extends StatelessWidget {
  final List<String> tagChips;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onSubmitted;

  const _TagChipInput({
    required this.tagChips,
    required this.inputController,
    required this.inputFocus,
    required this.onTagRemoved,
    required this.onTagAdded,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => inputFocus.requestFocus(),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search icon
            Icon(
              Icons.search_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            // Tag chips
            for (final tag in tagChips)
              _TagChip(
                tag: tag,
                onRemove: () => onTagRemoved(tag),
              ),
            // Text input
            IntrinsicWidth(
              child: TextField(
                controller: inputController,
                focusNode: inputFocus,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tagChips.isEmpty ? 'Search tags...' : 'Add tag...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    onTagAdded(v.trim());
                  } else {
                    onSubmitted(v);
                  }
                },
                // Space bar also adds tag
                onChanged: (v) {
                  if (v.endsWith(' ') && v.trim().isNotEmpty) {
                    onTagAdded(v.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onRemove;

  const _TagChip({required this.tag, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 26,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag.replaceAll('_', ' '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: theme.colorScheme.primary.withOpacity(0.7),
            ),
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
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFilters
                    ? theme.colorScheme.primary.withOpacity(0.4)
                    : theme.colorScheme.outline.withOpacity(0.2),
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
            color: theme.colorScheme.outline.withOpacity(0.12),
            width: 0.5,
          ),
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final tag = suggestions[index];
          return InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(tag);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.tag_rounded,
                    size: 13,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tag.replaceAll('_', ' '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.north_west_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
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

// ─── Source Filter Chips ──────────────────────────────────────────────────

class _SourceChips extends StatelessWidget {
  final SearchState state;
  const _SourceChips({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: BooruSource.values.take(4).map((source) {
            final isActive = state.activeSources.contains(source);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SourceChip(
                source: source,
                isActive: isActive,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<SearchBloc>()
                      .add(SearchSourceToggled(source));
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final BooruSource source;
  final bool isActive;
  final VoidCallback onTap;

  const _SourceChip({
    required this.source,
    required this.isActive,
    required this.onTap,
  });

  Color get _sourceColor {
    switch (source) {
      case BooruSource.rule34xxx:
        return const Color(0xFF7C6FFF);
      case BooruSource.e621:
        return const Color(0xFF4ECDC4);
      case BooruSource.gelbooru:
        return const Color(0xFFFF7CA0);
      case BooruSource.paheal:
        return const Color(0xFFFFCC7C);
      default:
        return const Color(0xFF7C8FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _sourceColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.18) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : theme.colorScheme.outline.withOpacity(0.15),
            width: isActive ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          source.shortName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Results Header ───────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  final SearchState state;
  const _ResultsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Accurate count display
              // hasMore=true → at least one source has more pages;
              // show "N+ results" to signal this is not the final total.
              // hasMore=false → all sources are exhausted; show exact count.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.hasMore
                      ? '${state.posts.length}+ loaded'
                      : '${state.posts.length} result${state.posts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (state.tagString.isNotEmpty)
                Flexible(
                  child: Text(
                    '"${state.tagString}"',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (state.failedSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${state.failedSources.map((s) => s.shortName).join(', ')} failed — results may be incomplete.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Empty / Loading / Error States ──────────────────────────────────────

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
                color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.image_search_rounded,
                size: 40,
                color: theme.colorScheme.primary.withOpacity(0.5),
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
              'Type a tag above and press enter,\nor tap a suggestion to search',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: theme.colorScheme.error.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
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
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
          ),
          const SizedBox(height: 16),
          Text('No results found', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Try different tags or change\nyour active sources',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
