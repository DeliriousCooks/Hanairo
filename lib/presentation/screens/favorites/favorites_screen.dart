import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';
import '../../widgets/grid/post_grid.dart';
import '../../blocs/search_bloc.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Post> _favorites = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<LocalRepository>();
    setState(() => _favorites = repo.getFavorites());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          title: const Text('Favorites'),
          backgroundColor: theme.scaffoldBackgroundColor,
          pinned: true,
          actions: [
            if (_favorites.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.sort_rounded),
                onPressed: () {},
              ),
          ],
        ),
        if (_favorites.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text('No favorites yet', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tap ♥ on any post to save it here',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          PostGridSliver(
            posts: _favorites,
            onPostTapped: (post, index) {
              context.push('/viewer', extra: {
                'posts': _favorites,
                'index': index,
              });
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}
