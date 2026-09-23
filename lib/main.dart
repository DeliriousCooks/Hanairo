import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_settings.dart';
import 'core/utils/logger.dart';
import 'presentation/widgets/common/glass_container.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/local_repository.dart';
import 'presentation/blocs/search_bloc.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/search/search_screen.dart';
import 'presentation/screens/viewer/viewer_screen.dart';
import 'presentation/screens/favorites/favorites_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'domain/entities/post.dart';

final _localRepo = LocalRepository();
final _searchRepo = SearchRepository();
late final ThemeController _themeController;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Transparent status bar, immersive dark
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await _localRepo.init();
  _themeController = ThemeController(_localRepo);
  
  // Restore credentials
  final creds = await _localRepo.loadCredentials();
  for (final entry in creds.entries) {
    final source = BooruSource.values.firstWhere(
      (s) => s.name == entry.key,
      orElse: () => BooruSource.rule34xxx,
    );
    final username = entry.value['username'];
    final credential = entry.value['credential'];
    if (username != null && credential != null) {
      await _searchRepo.login(source, username, credential);
    }
  }

  runApp(const BooruApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return SearchScreen(initialQuery: query);
          },
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => const FavoritesScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/viewer',
      // Uses pageBuilder (not the default builder:) so we can hand back a
      // CupertinoPage with allowSnapshotting: false. Without that, iOS's
      // interactive swipe-back gesture drags a pre-rendered *snapshot
      // texture* of this route around instead of the live widget - and if
      // that snapshot gets captured before the viewer's image has
      // finished painting (very likely for a route with an async image),
      // the user drags around a blank grey placeholder instead of the
      // actual photo. allowSnapshotting: false forces the live widget to
      // keep rendering during the gesture instead, which is the
      // documented fix for exactly this class of bug.
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final posts = extra?['posts'] as List<Post>? ?? [];
        final index = extra?['index'] as int? ?? 0;
        return CupertinoPage(
          key: state.pageKey,
          allowSnapshotting: false,
          child: ViewerScreen(posts: posts, initialIndex: index),
        );
      },
    ),
    GoRoute(
      path: '/auth/:source',
      builder: (context, state) {
        final sourceName = state.pathParameters['source']!;
        final source = BooruSource.values.firstWhere(
          (s) => s.name == sourceName,
          orElse: () => BooruSource.rule34xxx,
        );
        return AuthScreen(source: source);
      },
    ),
  ],
);

class BooruApp extends StatelessWidget {
  const BooruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LocalRepository>.value(value: _localRepo),
        RepositoryProvider<SearchRepository>.value(value: _searchRepo),
      ],
      child: BlocProvider(
        create: (ctx) => SearchBloc(
          searchRepo: _searchRepo,
          localRepo: _localRepo,
        ),
        child: _ThemeWrapper(),
      ),
    );
  }
}

/// Makes the app-wide [ThemeController] available to any descendant via
/// `ThemeScope.of(context)`. Widgets that call this inside build() are
/// automatically rebuilt whenever the controller's theme settings change.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope.of() called with no ThemeScope ancestor');
    return scope!.notifier!;
  }
}

class _ThemeWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp.router(
            title: 'BooruWave',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(
              brightness: Brightness.light,
              accent: _themeController.accent.color,
            ),
            darkTheme: AppTheme.build(
              brightness: Brightness.dark,
              accent: _themeController.accent.color,
            ),
            themeMode: _themeController.isDark ? ThemeMode.dark : ThemeMode.light,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = ['/', '/search', '/favorites', '/settings'];

  int _indexForLocation(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _routes.indexOf(location);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true,
          // Each individual tab screen now paints its own opaque copy of
          // this gradient (see PageBackground) so page transitions don't
          // ghost/overlap - this body is just a plain passthrough.
          body: child,
          bottomNavigationBar: _BottomNav(
            selectedIndex: _indexForLocation(context),
            glass: themeController.glass,
            onDestinationSelected: (index) {
              context.go(_routes[index]);
            },
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final GlassThickness glass;
  final ValueChanged<int> onDestinationSelected;

  const _BottomNav({
    required this.selectedIndex,
    required this.glass,
    required this.onDestinationSelected,
  });

  static const _items = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_outlined, selectedIcon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.favorite_outline_rounded, selectedIcon: Icons.favorite_rounded, label: 'Favorites'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GlassContainer(
        thickness: glass,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].icon,
                  selectedIcon: _items[i].selectedIcon,
                  label: _items[i].label,
                  selected: i == selectedIndex,
                  color: theme.colorScheme.primary,
                  onTap: () => onDestinationSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.9) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
            if (!selected) ...[
              const SizedBox(height: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
