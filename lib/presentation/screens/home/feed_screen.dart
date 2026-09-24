import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../data/repositories/search_repository.dart';
import '../../../domain/entities/post.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/page_background.dart';
import '../../widgets/grid/post_grid.dart';
import '../../../main.dart' show ThemeScope;

enum _FeedOrder { popular, latest }
enum _FeedMode { fresh, savedTags }
enum _FeedLayout { grid, single }

bool _sourceRequiresCredentials(BooruSource source, String? error) {
  if (source != BooruSource.rule34xxx && source != BooruSource.gelbooru) {
    return false;
  }
  return RegExp(r'auth|api.?key|user.?id|credential|401|403')
      .hasMatch((error ?? '').toLowerCase());
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = const [];
  List<BooruSource> _sources = const [];
  List<BooruSource> _failedSources = const [];
  Map<BooruSource, String> _sourceErrors = const {};
  BooruSource? _sourceFilter;
  _FeedOrder _order = _FeedOrder.popular;
  _FeedMode _feedMode = _FeedMode.fresh;
  _FeedLayout _layout = _FeedLayout.grid;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _layout = context.read<LocalRepository>().getSetting<String>(
                  'feed_layout',
                  'grid',
                ) ==
            'single'
        ? _FeedLayout.single
        : _FeedLayout.grid;
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final local = context.read<LocalRepository>();
      final search = context.read<SearchRepository>();
      final sourceNames = local.getActiveSources();
      final sources = sourceNames
          .map((name) => BooruSource.values.firstWhere(
                (source) => source.name == name,
                orElse: () => BooruSource.rule34xxx,
              ))
          .toSet()
          .toList();
      if (sources.isEmpty) {
        throw StateError('Choose at least one booru source in Settings.');
      }

      late final Map<BooruSource, SourceResult> result;
      if (_feedMode == _FeedMode.savedTags) {
        final tags = local.getFavoriteTags().take(4).toList();
        if (tags.isEmpty) {
          result = {
            for (final source in sources) source: const SourceResult([]),
          };
        } else {
          final taggedResults = await Future.wait(tags.map((tag) =>
              search.searchPerSourceDetailed(SearchQuery(
                tags: [tag],
                sources: sources,
                ratingFilter: local.isSafeMode() ? ContentRating.safe : null,
                limit: 6,
              ))));
          final postsBySource = {for (final source in sources) source: <Post>[]};
          final failedBySource = <BooruSource>{};
          final errorsBySource = <BooruSource, String>{};
          for (final tagResult in taggedResults) {
            for (final entry in tagResult.entries) {
              postsBySource[entry.key]!.addAll(entry.value.posts);
              if (entry.value.failed) failedBySource.add(entry.key);
              if (entry.value.errorMessage != null) {
                errorsBySource[entry.key] = entry.value.errorMessage!;
              }
            }
          }
          result = {
            for (final source in sources)
              source: SourceResult(
                postsBySource[source]!,
                failed: failedBySource.contains(source),
                errorMessage: errorsBySource[source],
              ),
          };
        }
      } else {
        result = await search.searchPerSourceDetailed(SearchQuery(
          tags: const [],
          sources: sources,
          ratingFilter: local.isSafeMode() ? ContentRating.safe : null,
          limit: 30,
        ));
      }
      final posts = result.values
          .expand((sourceResult) => sourceResult.posts)
          .where((post) => !local.isBlacklisted(post))
          .map((post) => post.copyWith(
                isFavorited: local.isFavorite(post.uniqueId),
              ))
          .toList();
      final seen = <String>{};
      final unique = posts.where((post) => seen.add(post.uniqueId)).toList();
      _sortPosts(unique);
      final authFailures = result.entries
          .where((entry) => entry.value.failed)
          .where((entry) => _sourceRequiresCredentials(
                entry.key,
                entry.value.errorMessage,
              ))
          .map((entry) => entry.key)
          .toList();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _posts = unique;
        _failedSources = result.entries
            .where((entry) => entry.value.failed)
            .map((entry) => entry.key)
            .toList();
        _sourceErrors = {
          for (final entry in result.entries)
            if (entry.value.errorMessage != null)
              entry.key: entry.value.errorMessage!,
        };
        _loading = false;
        if (result.values.every((sourceResult) => sourceResult.failed)) {
          _error = authFailures.isNotEmpty
              ? '${authFailures.map((source) => source.shortName).join(', ')} needs API credentials to load the feed.'
              : 'Your booru sources could not be reached. Try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the feed. Check your connection and try again.';
      });
    }
  }

  void _sortPosts(List<Post> posts) {
    if (_feedMode == _FeedMode.fresh && _order == _FeedOrder.popular) {
      posts.sort((a, b) => b.score.compareTo(a.score));
    } else {
      posts.sort((a, b) => (b.createdAt ?? DateTime(1970))
          .compareTo(a.createdAt ?? DateTime(1970)));
    }
  }

  List<Post> get _visiblePosts {
    final posts = _sourceFilter == null
        ? _posts.toList()
        : _posts.where((post) => post.source == _sourceFilter).toList();
    _sortPosts(posts);
    return posts;
  }

  Future<void> _toggleFavorite(Post post) async {
    final local = context.read<LocalRepository>();
    final saving = !local.isFavorite(post.uniqueId);
    if (saving) {
      await local.addFavorite(post);
    } else {
      await local.removeFavorite(post.uniqueId);
    }
    if (!mounted) return;
    setState(() {
      _posts = _posts
          .map((item) => item.uniqueId == post.uniqueId
              ? item.copyWith(isFavorited: saving)
              : item)
          .toList();
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(saving ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visiblePosts;
    final authFailedSources = _failedSources
        .where((source) => _sourceRequiresCredentials(
              source,
              _sourceErrors[source],
            ))
        .toList();
    final top = MediaQuery.of(context).padding.top;

    return PageBackground(
      child: RefreshIndicator.adaptive(
        onRefresh: _loadFeed,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: visible.isEmpty && !_loading
              ? const ClampingScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.24),
                          const Color(0xFF365FD2).withOpacity(0.16),
                          const Color(0xFFCC67E7).withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.13),
                          blurRadius: 28,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          right: -26,
                          top: -58,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                const Color(0xFF8C70FF).withOpacity(0.34),
                                const Color(0xFF8C70FF).withOpacity(0.01),
                              ]),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 46,
                          bottom: -76,
                          child: Container(
                            width: 142,
                            height: 142,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                const Color(0xFF46D7E8).withOpacity(0.22),
                                const Color(0xFF46D7E8).withOpacity(0.01),
                              ]),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                          child: Row(children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF9D7BFF), Color(0xFF367FEF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withOpacity(0.34),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(5),
                              child: SvgPicture.asset('assets/images/booruwave_mark.svg'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('BooruWave', style: theme.textTheme.titleLarge),
                                  const SizedBox(height: 2),
                                  Text('Your daily wave of art',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      )),
                                  const SizedBox(height: 7),
                                  Row(children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF6DE5CA),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _sources.isEmpty
                                          ? 'READY TO DISCOVER'
                                          : 'LIVE FROM ${_sources.length} BOORU SITES',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.74),
                                        letterSpacing: 0.75,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Account',
                              onPressed: () => context.go('/account'),
                              icon: Icon(Icons.person_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.65),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder<int>(
                valueListenable:
                    context.read<LocalRepository>().favoriteTagsRevision,
                builder: (context, _, __) {
                  final tags = context.read<LocalRepository>().getFavoriteTags();
                  if (tags.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved tags', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 7),
                        SizedBox(
                          height: 34,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: tags.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 7),
                            itemBuilder: (context, index) {
                              final tag = tags[index];
                              return ActionChip(
                                visualDensity: VisualDensity.compact,
                                label: Text(tag.replaceAll('_', ' ')),
                                onPressed: () => context.go(
                                  '/search?q=${Uri.encodeQueryComponent(tag)}',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _SearchEntry(onTap: () {
                  HapticFeedback.selectionClick();
                  context.go('/search');
                }),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _feedMode == _FeedMode.savedTags
                              ? 'Saved tag mix'
                              : 'Fresh finds',
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                            _feedMode == _FeedMode.savedTags
                                ? 'Recent posts from your saved tags'
                                : 'Across your favorite booru sites',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                  SegmentedButton<_FeedLayout>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _FeedLayout.grid,
                        icon: Icon(Icons.grid_view_rounded, size: 17),
                        tooltip: 'Grid feed',
                      ),
                      ButtonSegment(
                        value: _FeedLayout.single,
                        icon: Icon(Icons.view_agenda_outlined, size: 17),
                        tooltip: 'Single post feed',
                      ),
                    ],
                    selected: {_layout},
                    onSelectionChanged: (selection) =>
                        _setLayout(selection.first),
                  ),
                  IconButton(
                    tooltip: 'Refresh feed',
                    onPressed: _loading ? null : _loadFeed,
                    icon: Icon(Icons.refresh_rounded,
                        color: theme.colorScheme.primary),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _OrderPill(
                      label: 'Fresh',
                      selected: _feedMode == _FeedMode.fresh,
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => _setFeedMode(_FeedMode.fresh),
                    ),
                    const SizedBox(width: 8),
                    _OrderPill(
                      label: 'Tag mix',
                      selected: _feedMode == _FeedMode.savedTags,
                      icon: Icons.bookmarks_outlined,
                      onTap: () => _setFeedMode(_FeedMode.savedTags),
                    ),
                    const SizedBox(width: 8),
                    _OrderPill(
                      label: 'Popular',
                      selected: _order == _FeedOrder.popular,
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => _setOrder(_FeedOrder.popular),
                    ),
                    const SizedBox(width: 8),
                    _OrderPill(
                      label: 'Latest',
                      selected: _order == _FeedOrder.latest,
                      icon: Icons.schedule_rounded,
                      onTap: () => _setOrder(_FeedOrder.latest),
                    ),
                    if (_sources.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                        color: theme.colorScheme.outline.withOpacity(0.25),
                      ),
                      const SizedBox(width: 4),
                      _SourcePill(
                        label: 'All',
                        selected: _sourceFilter == null,
                        onTap: () => setState(() => _sourceFilter = null),
                      ),
                      for (final source in _sources)
                        Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: _SourcePill(
                            label: source.shortName,
                            selected: _sourceFilter == source,
                            onTap: () => setState(() => _sourceFilter = source),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_failedSources.isNotEmpty &&
                !_loading &&
                _failedSources.length < _sources.length)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                  child: _SourceFailureNotice(
                    sources: _failedSources,
                    errors: _sourceErrors,
                    onRetry: _loadFeed,
                  ),
                ),
              ),
            if (_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Finding your next favorite…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ]),
                ),
              )
            else if (_error != null && _posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Feed unavailable',
                  message: _error!,
                  action: authFailedSources.isNotEmpty
                      ? Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: authFailedSources
                              .map((source) => FilledButton.icon(
                                    onPressed: () =>
                                        context.push('/auth/${source.name}'),
                                    icon: const Icon(Icons.key_rounded),
                                    label: Text('Connect ${source.shortName}'),
                                  ))
                              .toList(),
                        )
                      : FilledButton.icon(
                          onPressed: _loadFeed,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FeedMessage(
                  icon: Icons.image_search_rounded,
                  title: 'No posts yet',
                  message: _sourceFilter == null
                      ? (_feedMode == _FeedMode.savedTags
                          ? 'Save tags from Search to build a feed of recent posts for them.'
                          : 'Choose a source in Settings, then come back to your feed.')
                      : 'No posts from this source right now. Try another source.',
                  action: TextButton(
                    onPressed: () => context.go(
                      _feedMode == _FeedMode.savedTags ? '/search' : '/settings',
                    ),
                    child: Text(
                      _feedMode == _FeedMode.savedTags
                          ? 'Find tags'
                          : 'Manage sources',
                    ),
                  ),
                ),
              )
            else ...[
              PostGridSliver(
                key: ValueKey(
                    '${_feedMode.name}-${_layout.name}-${_order.name}-${_sourceFilter?.name}'),
                posts: visible,
                columns: _layout == _FeedLayout.grid ? 2 : 1,
                onFavoriteTapped: _toggleFavorite,
                onPostTapped: (post, index) {
                  context.push('/viewer', extra: {
                    'posts': visible,
                    'index': index,
                  });
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 112)),
            ],
          ],
        ),
      ),
    );
  }

  void _setOrder(_FeedOrder order) {
    setState(() {
      _order = order;
      _sortPosts(_posts);
    });
    HapticFeedback.selectionClick();
  }

  void _setFeedMode(_FeedMode mode) {
    if (_feedMode == mode) return;
    setState(() {
      _feedMode = mode;
      if (mode == _FeedMode.savedTags) _order = _FeedOrder.latest;
    });
    HapticFeedback.selectionClick();
    _loadFeed();
  }

  void _setLayout(_FeedLayout layout) {
    if (_layout == layout) return;
    setState(() => _layout = layout);
    context.read<LocalRepository>().setSetting<String>(
          'feed_layout',
          layout.name,
        );
    HapticFeedback.selectionClick();
  }
}

class _SourceFailureNotice extends StatelessWidget {
  final List<BooruSource> sources;
  final Map<BooruSource, String> errors;
  final VoidCallback onRetry;

  const _SourceFailureNotice({
    required this.sources,
    required this.errors,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsCredentials = sources
        .where((source) => _sourceRequiresCredentials(source, errors[source]))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              needsCredentials.isNotEmpty
                  ? '${needsCredentials.map((source) => source.shortName).join(', ')} needs API credentials. Feed results may be incomplete.'
                  : '${sources.map((source) => source.shortName).join(', ')} unavailable. Feed results may be incomplete.',
              style: theme.textTheme.labelMedium,
            ),
          ),
          if (needsCredentials.isNotEmpty)
            for (final source in needsCredentials)
              IconButton(
                tooltip: 'Connect ${source.shortName}',
                onPressed: () => context.push('/auth/${source.name}'),
                icon: const Icon(Icons.key_rounded, size: 18),
                color: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              )
          else
            IconButton(
              tooltip: 'Retry feed',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              color: theme.colorScheme.primary,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: GlassContainer(
        thickness: _glass(context),
        borderRadius: BorderRadius.circular(17),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(Icons.search_rounded,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Search tags, artists, characters…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Icon(Icons.tune_rounded,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }

  GlassThickness _glass(BuildContext context) => ThemeScope.of(context).glass;
}

class _OrderPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _OrderPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      avatar: Icon(icon, size: 15,
          color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.62),
      selectedColor: theme.colorScheme.primary.withOpacity(0.88),
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withOpacity(0.2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SourcePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: theme.textTheme.labelSmall?.copyWith(
        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      backgroundColor: Colors.transparent,
      selectedColor: theme.colorScheme.primary.withOpacity(0.12),
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary.withOpacity(0.45)
            : theme.colorScheme.outline.withOpacity(0.22),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget action;
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 17),
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 14),
          action,
        ],
      ),
    );
  }
}
