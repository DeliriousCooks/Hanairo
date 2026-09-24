import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';
import '../../blocs/search_bloc.dart';
import '../../widgets/common/page_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeContent();
  }
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localRepo = context.read<LocalRepository>();
    final theme = Theme.of(context);
    final history = localRepo.getSearchHistory();
    final favorites = localRepo.getFavorites().take(6).toList();

    return PageBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _Header(),
              ),
            ),
          ),

          // ─── Quick Search ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _QuickSearchBar(),
                ),
              ),
            ),
          ),

          // ─── Sources ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(title: 'Sources', onSeeAll: null),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _SourcesRow(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ─── Recent Searches ──────────────────────────────────────────────
          if (history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(title: 'Recent Searches', onSeeAll: null),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _RecentSearches(history: history),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],

          // ─── Recent Favorites Preview ─────────────────────────────────────
          if (favorites.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Recent Favorites',
                onSeeAll: () => context.go('/favorites'),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: _FavoritesPreview(favorites: favorites),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
          ],

          // ─── Popular Tags ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(title: 'Popular Tags', onSeeAll: null),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: _PopularTagsGrid(),
            ),
          ),

          // Bottom nav padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'BooruWave',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.go('/settings'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Discover. Save. Customize.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Search Bar ─────────────────────────────────────────────────────

class _QuickSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.go('/search');
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            const SizedBox(width: 12),
            Text(
              'Search tags, artists, characters...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            const Spacer(),
            // Mic icon hint
            Icon(
              Icons.mic_none_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sources Row ──────────────────────────────────────────────────────────

class _SourcesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (p, c) => p.activeSources != c.activeSources,
      builder: (context, state) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: BooruSource.values.take(4).map((source) {
            final isActive = state.activeSources.contains(source);
            return _SourceChip(
              source: source,
              isActive: isActive,
              onTap: () {
                HapticFeedback.selectionClick();
                context.read<SearchBloc>().add(SearchSourceToggled(source));
              },
            );
          }).toList(),
        );
      },
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

  Color get _color {
    switch (source) {
      case BooruSource.rule34xxx:
        return const Color(0xFFA180FF);
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
    final color = _color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.14)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.45)
                : theme.colorScheme.outline.withOpacity(0.15),
            width: isActive ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? color : color.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              source.domain,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? color : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'See all',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Recent Searches ──────────────────────────────────────────────────────

class _RecentSearches extends StatelessWidget {
  final List<String> history;
  const _RecentSearches({required this.history});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: history.take(12).map((tag) {
        return _HistoryChip(tag: tag);
      }).toList(),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String tag;
  const _HistoryChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final bloc = context.read<SearchBloc>();
        bloc.add(SearchSubmitted(tag, bloc.state.activeSources));
        context.go('/search?q=${Uri.encodeComponent(tag)}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            const SizedBox(width: 6),
            Text(
              tag,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Favorites Preview ────────────────────────────────────────────────────

class _FavoritesPreview extends StatelessWidget {
  final List<Post> favorites;
  const _FavoritesPreview({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final post = favorites[index];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _FavoritePreviewCard(post: post),
        );
      },
    );
  }
}

class _FavoritePreviewCard extends StatelessWidget {
  final Post post;
  const _FavoritePreviewCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/viewer', extra: {
          'posts': [post],
          'index': 0,
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 110,
          height: 150,
          color: theme.colorScheme.surfaceContainerHighest,
          child: post.thumbnailUrl != null
              ? CachedNetworkImage(
                  imageUrl: post.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 24),
                  ),
                )
              : const Center(
                  child: Icon(Icons.image_outlined, size: 32),
                ),
        ),
      ),
    );
  }
}

// ─── Popular Tags Grid ────────────────────────────────────────────────────

class _PopularTagsGrid extends StatelessWidget {
  static const _popularTags = [
    ('solo', Icons.person_outline_rounded, 'character'),
    ('animated', Icons.movie_outlined, 'meta'),
    ('high_score', Icons.star_outline_rounded, 'meta'),
    ('original', Icons.brush_outlined, 'artist'),
    ('multiple_girls', Icons.group_outlined, 'character'),
    ('uncensored', Icons.visibility_outlined, 'meta'),
    ('4k', Icons.hd_outlined, 'meta'),
    ('score:>100', Icons.trending_up_rounded, 'meta'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _popularTags.map((tag) {
        return _PopularTagChip(
          label: tag.$1,
          icon: tag.$2,
          category: tag.$3,
        );
      }).toList(),
    );
  }
}

class _PopularTagChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String category;

  const _PopularTagChip({
    required this.label,
    required this.icon,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final tagColor = ext?.tagColors[category] ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final bloc = context.read<SearchBloc>();
        bloc.add(SearchSubmitted(label, bloc.state.activeSources));
        context.go('/search?q=${Uri.encodeComponent(label)}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: tagColor.withOpacity(0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tagColor.withOpacity(0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: tagColor),
            const SizedBox(width: 6),
            Text(
              label.replaceAll('_', ' '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: tagColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
