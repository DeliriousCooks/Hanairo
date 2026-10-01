import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';
import '../../widgets/grid/post_grid.dart';
import '../../widgets/common/page_background.dart';

enum _FavoritesSection { posts, tags }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with AutomaticKeepAliveClientMixin {
  List<Post> _favorites = [];
  int _gridColumns = 2;
  _FavoritesSection _section = _FavoritesSection.posts;
  late LocalRepository _localRepository;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _localRepository = context.read<LocalRepository>();
    _gridColumns = _localRepository.getGridColumns();
    _localRepository.favoritesRevision.addListener(_onFavoritesChanged);
    _localRepository.gridColumnsRevision.addListener(_onGridColumnsChanged);
    _load();
  }

  @override
  void dispose() {
    _localRepository.favoritesRevision.removeListener(_onFavoritesChanged);
    _localRepository.gridColumnsRevision.removeListener(_onGridColumnsChanged);
    super.dispose();
  }

  void _onFavoritesChanged() => _load();

  void _onGridColumnsChanged() {
    final columns = _localRepository.getGridColumns();
    if (mounted && columns != _gridColumns) {
      setState(() => _gridColumns = columns);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final favs = _localRepository.getFavorites();
    final oldIds = _favorites.map((post) => post.uniqueId).join('|');
    final newIds = favs.map((post) => post.uniqueId).join('|');
    if (newIds != oldIds) {
      setState(() => _favorites = favs);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return PageBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 20,
                20,
                16,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.ratingExplicit.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 18,
                      color: AppColors.ratingExplicit,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Favorites', style: theme.textTheme.headlineLarge),
                  const Spacer(),
                  if (_section == _FavoritesSection.posts && _favorites.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_favorites.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (_section == _FavoritesSection.tags)
                    ValueListenableBuilder<int>(
                      valueListenable: _localRepository.favoriteTagsRevision,
                      builder: (context, _, __) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_localRepository.getFavoriteTags().length} tags',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: SegmentedButton<_FavoritesSection>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _FavoritesSection.posts,
                    icon: Icon(Icons.favorite_outline_rounded),
                    label: Text('Posts'),
                  ),
                  ButtonSegment(
                    value: _FavoritesSection.tags,
                    icon: Icon(Icons.tag_rounded),
                    label: Text('Favorite tags'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (selection) =>
                    setState(() => _section = selection.first),
              ),
            ),
          ),

          // Content
          if (_section == _FavoritesSection.tags)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ValueListenableBuilder<int>(
                valueListenable: _localRepository.favoriteTagsRevision,
                builder: (context, _, __) {
                  final tags = _localRepository.getFavoriteTags();
                  if (tags.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sell_outlined,
                                size: 42,
                                color: theme.colorScheme.primary.withOpacity(0.55)),
                            const SizedBox(height: 16),
                            Text('No favorite tags yet',
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text(
                              'Open a post and press and hold a tag to save it here.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: tags.map((tag) {
                          return Container(
                            constraints: const BoxConstraints(minWidth: 154),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh
                                  .withOpacity(0.82),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: theme.colorScheme.primary.withOpacity(0.22),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(15),
                                  onTap: () => context.go(
                                    '/search?q=${Uri.encodeQueryComponent(tag)}',
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.tag_rounded,
                                            size: 16,
                                            color: theme.colorScheme.primary),
                                        const SizedBox(width: 7),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 190),
                                          child: Text(
                                            tag.replaceAll('_', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove favorite tag',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _localRepository.toggleFavoriteTag(tag),
                                  icon: Icon(Icons.close_rounded,
                                      size: 17,
                                      color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (_favorites.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.ratingExplicit.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.favorite_outline_rounded,
                          size: 40,
                          color: AppColors.ratingExplicit.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No favorites yet',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap ♥ on any post to save it here',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            PostGridSliver(
              posts: _favorites,
              columns: _gridColumns,
              onPostTapped: (post, index) {
                context.push('/viewer', extra: {
                  'posts': _favorites,
                  'index': index,
                });
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
