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
    _inputFocus.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
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
        // The shell scaffold handles the keyboard inset. Resizing this nested
        // scaffold as well double-applies the inset and leaves a dead strip.
        resizeToAvoidBottomInset: false,
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
                      PostGridSliver(
                        // Stable key: only rebuild when posts list actually
                        // changes identity (prevents grid reflow on
                        // unrelated state updates like loadingMore status)
                        key: ValueKey(state.posts.length),
                        posts: state.posts,
                          columns: context
                              .read<LocalRepository>()
                              .getGridColumns(),
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
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main search bar container
          LiquidGlassSurface(
            sigma: 20,
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(showSuggestions ? 16 : 22),
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
              buildWhen: (p, c) =>
                  p.tagSuggestions != c.tagSuggestions ||
                  p.tagSuggestionCounts != c.tagSuggestionCounts,
              builder: (context, state) {
                if (state.tagSuggestions.isEmpty) return const SizedBox();
                return _SuggestionsDropdown(
                  suggestions: state.tagSuggestions,
                  counts: state.tagSuggestionCounts,
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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(
            theme.brightness == Brightness.dark ? 0.55 : 0.42,
          ),
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: tagChips.isEmpty ? 220 : 150,
                  maxWidth: 320,
                ),
                child: TextField(
                  controller: inputController,
                  focusNode: inputFocus,
                  textAlignVertical: TextAlignVertical.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tagChips.isEmpty ? 'Search tags...' : 'Add tag...',
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
                  : theme.colorScheme.surfaceContainerHighest.withOpacity(
                      theme.brightness == Brightness.dark ? 0.48 : 0.36,
                    ),
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
