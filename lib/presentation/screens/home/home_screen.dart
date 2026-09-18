import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';
import '../../blocs/search_bloc.dart';
import '../../widgets/common/glass_card.dart';
import '../../widgets/common/source_badge.dart';

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
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ─── Large Title Header ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _Header(),
            ),
          ),
        ),

        // ─── Quick Search Bar ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: _QuickSearchBar(),
              ),
            ),
          ),
        ),

        // ─── Active Sources ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(title: 'Sources', onSeeAll: null),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SourcesRow(),
          ),
        ),

        // ─── Recent Searches ─────────────────────────────────────────────────
        if (history.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Recent Searches',
              onSeeAll: null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _RecentSearches(history: history),
            ),
          ),
        ],

        // ─── Recent Favorites Preview ────────────────────────────────────────
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
        ],

        // ─── Popular Tags ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _SectionHeader(title: 'Popular Tags', onSeeAll: null),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: _PopularTagsGrid(),
          ),
        ),

        // Bottom padding for nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 24,
        20,
        24,
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
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
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
                'Booru Gallery',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Multi-source image aggregator',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

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
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search tags, artists, characters...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Search',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              ...BooruSource.values.take(4).map((source) {
                final isActive = state.activeSources.contains(source);
                return Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 20),
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
              }),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.5)
                : theme.colorScheme.outline.withOpacity(0.3),
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
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              source.domain,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
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
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
        context.read<SearchBloc>().add(
              SearchSubmitted(
                tag,
                context.read<SearchBloc>().state.activeSources,
              ),
            );
        context.go('/search?q=${Uri.encodeComponent(tag)}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
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
          padding: const EdgeInsets.only(right: 12),
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
        context.push('/viewer', extra: {
          'posts': [post],
          'index': 0,
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 120,
          height: 160,
          color: theme.colorScheme.surfaceContainerHighest,
          child: post.thumbnailUrl != null
              ? Image.network(
                  post.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
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

class _PopularTagsGrid extends StatelessWidget {
  static const _popularTags = [
    ('solo', Icons.person_outline_rounded, 'character'),
    ('animated', Icons.movie_outlined, 'meta'),
    ('high_score', Icons.star_outline_rounded, 'meta'),
    ('original', Icons.brush_outlined, 'artist'),
    ('multiple_girls', Icons.group_outlined, 'character'),
    ('uncensored', Icons.visibility_outlined, 'meta'),
    ('4k', Icons.hd_outlined, 'meta'),
    ('nsfw', Icons.warning_amber_outlined, 'rating'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          color: tagColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: tagColor.withOpacity(0.3),
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
              style: theme.textTheme.labelMedium?.copyWith(color: tagColor),
            ),
          ],
        ),
      ),
    );
  }
}
