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

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = const [];
  List<BooruSource> _sources = const [];
  BooruSource? _sourceFilter;
  _FeedOrder _order = _FeedOrder.popular;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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

      final result = await search.searchPerSourceDetailed(SearchQuery(
        tags: const [],
        sources: sources,
        ratingFilter: local.isSafeMode() ? ContentRating.safe : null,
        limit: 30,
      ));
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
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _posts = unique;
        _loading = false;
        if (result.values.every((sourceResult) => sourceResult.failed)) {
          _error = 'Your booru sources could not be reached. Pull to try again.';
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
    if (_order == _FeedOrder.popular) {
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
    final top = MediaQuery.of(context).padding.top;

    return PageBackground(
      child: RefreshIndicator.adaptive(
        onRefresh: _loadFeed,
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, top + 16, 20, 20),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary, const Color(0xFF528BEE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.24),
                          blurRadius: 17,
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
                      children: [
                        Text('BooruWave', style: theme.textTheme.titleLarge),
                        Text('Your daily wave of art',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Account',
                    onPressed: () => context.go('/account'),
                    icon: Icon(Icons.person_outline_rounded,
                        color: theme.colorScheme.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest.withOpacity(0.65),
                    ),
                  ),
                ]),
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
                        Text('Fresh finds', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 3),
                        Text('Across your favorite booru sites',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
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
                  action: FilledButton.icon(
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
                      ? 'Choose a source in Settings, then come back to your feed.'
                      : 'No posts from this source right now. Try another source.',
                  action: TextButton(
                    onPressed: () => context.go('/settings'),
                    child: const Text('Manage sources'),
                  ),
                ),
              )
            else ...[
              PostGridSliver(
                key: ValueKey('${_order.name}-${_sourceFilter?.name}'),
                posts: visible,
                columns: 2,
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
