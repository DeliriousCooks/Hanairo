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
import '../../widgets/common/liquid_glass_surface.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../core/tags/tag_translator.dart';

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
  final _chipScrollController = ScrollController();
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
    _chipScrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery == widget.initialQuery) return;

    _inputController.clear();
    final parts = widget.initialQuery.trim().isEmpty
        ? const <String>[]
        : widget.initialQuery.trim().split(RegExp(r'\s+'));
      setState(() {
        _tagChips
          ..clear()
          ..addAll(parts.where((part) => part.isNotEmpty));
      _inputText = '';
      _showSuggestions = false;
    });

    final bloc = context.read<SearchBloc>();
    bloc.add(SearchQueryChanged(''));
    if (parts.isEmpty) {
      bloc.add(SearchCleared());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_chipScrollController.hasClients) {
          _chipScrollController.jumpTo(
            _chipScrollController.position.maxScrollExtent,
          );
        }
        _submitSearch();
      });
    }
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chipScrollController.hasClients) {
          _chipScrollController.animateTo(
            _chipScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _inputController.clear();
    setState(() {
      _inputText = '';
      _showSuggestions = false;
    });
    context.read<SearchBloc>().add(SearchQueryChanged(''));
    // Selecting a suggestion only edits the query. Keep the keyboard ready so
    // the user can add more tags; the search runs when they press Enter.
    _inputFocus.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() => _tagChips.remove(tag));
    _inputFocus.requestFocus();
  }

  void _clearSearch() {
    _inputController.clear();
    setState(() {
      _tagChips.clear();
      _inputText = '';
      _showSuggestions = false;
    });
    context.read<SearchBloc>().add(SearchCleared());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
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
    _inputFocus.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.lightImpact();
    final bloc = context.read<SearchBloc>();
    if (query.isEmpty) {
      bloc.add(SearchCleared());
    } else {
      bloc.add(SearchSubmitted(query, bloc.state.activeSources));
    }
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
        // The shell scaffold handles the keyboard inset. Resizing this nested
        // scaffold as well double-applies the inset and leaves a dead strip.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ─── Main scrollable content ──────────────────────────────────
            BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                // Reserve room for the separate, scrollable tag row without
                // letting it overlap source filters or the results beneath.
                final headerHeight =
                    topPad + (_tagChips.isEmpty ? 80 : 120);

                return CustomScrollView(
                  controller: _scrollController,
                  // Avoid iOS bounce exposing an enlarging blank area when
                  // the current search has no cards to scroll through.
                  physics: const ClampingScrollPhysics(),
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
                    if (state.tagString.trim().isNotEmpty)
                      SliverToBoxAdapter(
                        child: _TranslatedQueries(state: state),
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
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _NoResultsState(
                          failedSources: state.failedSources,
                          sourceErrors: state.sourceErrors,
                          onRetry: () => context
                              .read<SearchBloc>()
                              .add(SearchRefreshed()),
                          onConnect: (source) =>
                              context.push('/auth/${source.name}'),
                        ),
                      )
                    else ...[
                      ValueListenableBuilder<int>(
                        valueListenable: context
                            .read<LocalRepository>()
                            .gridColumnsRevision,
                        builder: (context, _, __) {
                          final local = context.read<LocalRepository>();
                          return PostGridSliver(
                            // Keep the same grid instance while a pagination
                            // status changes; update its column preference live.
                            key: ValueKey(state.posts.length),
                            posts: state.posts,
                            columns: local.getGridColumns(),
                            onFavoriteTapped: (post) => context
                                .read<SearchBloc>()
                                .add(PostFavoriteToggled(post)),
                            onPostTapped: (post, index) {
                              _inputFocus.unfocus();
                              FocusScope.of(context).unfocus();
                              SystemChannels.textInput.invokeMethod<void>(
                                'TextInput.hide',
                              );
                              context.push('/viewer', extra: {
                                'posts': state.posts,
                                'index': index,
                              });
                            },
                          );
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

                    if (state.posts.isNotEmpty)
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),

            // ─── Floating search header ───────────────────────────────────
            _FloatingSearchHeader(
              tagChips: _tagChips,
              chipScrollController: _chipScrollController,
              inputController: _inputController,
              inputFocus: _inputFocus,
              showSuggestions: _showSuggestions,
              onTagRemoved: _removeTag,
              onTagAdded: _addTag,
              onSubmitted: (_) => _submitSearch(),
              onFilterTapped: () => _showFilterSheet(context),
              onClear: _clearSearch,
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
  final ScrollController chipScrollController;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final bool showSuggestions;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterTapped;
  final VoidCallback onClear;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onDismissSuggestions;

  const _FloatingSearchHeader({
    required this.tagChips,
    required this.chipScrollController,
    required this.inputController,
    required this.inputFocus,
    required this.showSuggestions,
    required this.onTagRemoved,
    required this.onTagAdded,
    required this.onSubmitted,
    required this.onFilterTapped,
    required this.onClear,
    required this.onSuggestionSelected,
    required this.onDismissSuggestions,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, topPad + 8, 14, 0),
            child: LiquidGlassSurface(
              sigma: 18,
              highContrast: true,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.26),
                        ),
                      ),
                      child: Icon(Icons.search_rounded,
                          size: 23,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TagChipInput(
                        tagChips: tagChips,
                        chipScrollController: chipScrollController,
                        inputController: inputController,
                        inputFocus: inputFocus,
                        onTagRemoved: onTagRemoved,
                        onTagAdded: onTagAdded,
                        onSubmitted: onSubmitted,
                      ),
                    ),
                    if (tagChips.isNotEmpty || inputController.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints.tightFor(width: 32, height: 40),
                        padding: EdgeInsets.zero,
                        onPressed: onClear,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 8),
                    _FilterButton(onTap: onFilterTapped),
                  ],
                ),
              ),
            ),
          ),

          // Suggestions dropdown
          if (showSuggestions)
            BlocBuilder<SearchBloc, SearchState>(
              buildWhen: (p, c) =>
                  p.tagSuggestions != c.tagSuggestions ||
                  p.tagSuggestionCounts != c.tagSuggestionCounts,
              builder: (context, state) {
                if (state.tagSuggestions.isEmpty) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: _SuggestionsDropdown(
                    suggestions: state.tagSuggestions,
                    counts: state.tagSuggestionCounts,
                    onSelected: onSuggestionSelected,
                  ),
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
  final ScrollController chipScrollController;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final ValueChanged<String> onTagRemoved;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onSubmitted;

  const _TagChipInput({
    required this.tagChips,
    required this.chipScrollController,
    required this.inputController,
    required this.inputFocus,
    required this.onTagRemoved,
    required this.onTagAdded,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: TextField(
            controller: inputController,
            focusNode: inputFocus,
            textAlignVertical: TextAlignVertical.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search tags…',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            // Space adds the completed word as a chip; Enter submits the query.
            onChanged: (value) {
              if (value.endsWith(' ') && value.trim().isNotEmpty) {
                onTagAdded(value.trim());
              }
            },
          ),
        ),
        if (tagChips.isNotEmpty) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: SingleChildScrollView(
              controller: chipScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tag in tagChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TagChip(
                        tag: tag,
                        onRemove: () => onTagRemoved(tag),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
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
      height: 34,
      padding: const EdgeInsets.only(left: 10, right: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              tag.replaceAll('_', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: hasFilters
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(
                      theme.brightness == Brightness.dark ? 0.48 : 0.36,
                    ),
              borderRadius: BorderRadius.circular(18),
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
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  const _SuggestionsDropdown({
    required this.suggestions,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                  if (counts.containsKey(tag)) ...[
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _formatTagCount(counts[tag]!),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: ' posts',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
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
        physics: const ClampingScrollPhysics(),
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
            width: isActive ? 1.2 : 0.9,
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

bool _sourceNeedsCredentials(BooruSource source, String? error) {
  if (source != BooruSource.rule34xxx && source != BooruSource.gelbooru) {
    return false;
  }
  final message = error?.toLowerCase() ?? '';
  return RegExp(r'auth|api.?key|user.?id|credential|401|403').hasMatch(message);
}

class _ResultsHeader extends StatelessWidget {
  final SearchState state;
  const _ResultsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countSummary = state.tagCounts.entries
        .map((entry) => '${entry.key.shortName} ${_formatTagCount(entry.value)}')
        .join('  ·  ');
    final combinedTagCount = state.tagCounts.values.fold<int>(0, (sum, count) => sum + count);
    final authSources = state.failedSources
        .where((source) => _sourceNeedsCredentials(
              source,
              state.sourceErrors[source],
            ))
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.posts.length} results loaded',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (state.tagString.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: state.tagString,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (state.tagCounts.isNotEmpty)
                            TextSpan(
                              text: '  ${_formatTagCount(combinedTagCount)}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
                if (state.tagString.trim().split(RegExp(r'\s+')).length == 1)
                  ValueListenableBuilder<int>(
                    valueListenable: context
                        .read<LocalRepository>()
                        .favoriteTagsRevision,
                    builder: (context, _, __) {
                      final local = context.read<LocalRepository>();
                      final saved = local.isFavoriteTag(state.tagString);
                      return IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: saved ? 'Remove saved tag' : 'Save this tag',
                        onPressed: () => local.toggleFavoriteTag(state.tagString),
                        icon: Icon(
                          saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 18,
                          color: saved
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
          if (state.tagCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Across enabled sites  ·  ',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.78),
                      ),
                    ),
                    TextSpan(
                      text: '${_formatTagCount(combinedTagCount)} total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: '  ·  $countSummary',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authSources.isNotEmpty
                                ? '${authSources.map((s) => s.shortName).join(', ')} needs API credentials — results may be incomplete.'
                                : '${state.failedSources.map((s) => s.shortName).join(', ')} unavailable — results may be incomplete.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (authSources.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: authSources
                            .map((source) => TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => context.push(
                                    '/auth/${source.name}',
                                  ),
                                  icon: const Icon(Icons.key_rounded, size: 14),
                                  label: Text('Connect ${source.shortName}'),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatTagCount(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}m';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
  return count.toString();
}

class _TranslatedQueries extends StatelessWidget {
  final SearchState state;
  const _TranslatedQueries({required this.state});

  @override
  Widget build(BuildContext context) {
    final tags = state.tagString.trim().split(RegExp(r'\s+'));
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: state.activeSources.map((source) {
          final translated = TagTranslator.translateForSource(tags, source);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.16)),
            ),
            child: Text(
              '${source.shortName} · ${translated.isEmpty ? 'no matching tags' : translated}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }).toList(),
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
  final List<BooruSource> failedSources;
  final Map<BooruSource, String> sourceErrors;
  final VoidCallback onRetry;
  final ValueChanged<BooruSource> onConnect;

  const _NoResultsState({
    required this.failedSources,
    required this.sourceErrors,
    required this.onRetry,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authSources = failedSources
        .where((source) => _sourceNeedsCredentials(
              source,
              sourceErrors[source],
            ))
        .toList();
    final hasFailures = failedSources.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFailures ? Icons.cloud_off_rounded : Icons.search_off_rounded,
            size: 52,
            color: hasFailures
                ? theme.colorScheme.error.withOpacity(0.6)
                : theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
          ),
          const SizedBox(height: 16),
          Text(
            hasFailures
                ? (authSources.isNotEmpty ? 'Connect this source' : 'Source unavailable')
                : 'No results found',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            !hasFailures
                ? 'Try different tags or change\nyour active sources'
                : authSources.isNotEmpty
                    ? '${authSources.map((s) => s.shortName).join(' and ')} requires API credentials before it can return posts.'
                    : '${failedSources.map((s) => s.shortName).join(', ')} could not return a usable response. Check your connection and try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (authSources.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: authSources
                  .map((source) => OutlinedButton.icon(
                        onPressed: () => onConnect(source),
                        icon: const Icon(Icons.key_rounded, size: 16),
                        label: Text('Connect ${source.shortName}'),
                      ))
                  .toList(),
            ),
          ] else if (hasFailures) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}
