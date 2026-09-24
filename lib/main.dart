import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_settings.dart';
import 'presentation/widgets/common/glass_container.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/local_repository.dart';
import 'presentation/blocs/search_bloc.dart';
import 'presentation/screens/home/feed_screen.dart';
import 'presentation/screens/search/search_screen.dart';
import 'presentation/screens/viewer/viewer_screen.dart';
import 'presentation/screens/favorites/favorites_screen.dart';
import 'presentation/screens/account/account_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'domain/entities/post.dart';

final _localRepo = LocalRepository();
final _searchRepo = SearchRepository();
late final ThemeController _themeController;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await _localRepo.init();
  _themeController = ThemeController(_localRepo);

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
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FeedScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return NoTransitionPage(
              child: SearchScreen(initialQuery: query),
            );
          },
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FavoritesScreen(),
          ),
        ),
        GoRoute(
          path: '/account',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AccountScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    // Viewer is outside the shell (full screen, no nav bar)
    GoRoute(
      path: '/viewer',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final posts = extra?['posts'] as List<Post>? ?? [];
        final index = extra?['index'] as int? ?? 0;
        return CupertinoPage(
          key: state.pageKey,
          // FIX: allowSnapshotting: false prevents the swipe-back gesture
          // from capturing a snapshot of an unfinished image load, which
          // was the iOS-side cause of the grey screen bug on back swipe.
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
              oled: _themeController.isOled,
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

  static const _routes = ['/', '/search', '/favorites', '/account', '/settings'];

  int _indexForLocation(BuildContext context) {
    // FIX: Use full path comparison and handle sub-paths correctly.
    // GoRouterState.of gives the current route state.
    final path = GoRouterState.of(context).uri.path;
    // Exact match first
    final exact = _routes.indexOf(path);
    if (exact != -1) return exact;
    // Prefix match for sub-routes (e.g. /search?q=foo → index 1)
    for (var i = _routes.length - 1; i >= 0; i--) {
      if (path.startsWith(_routes[i]) && _routes[i] != '/') {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Scaffold(
          // FIX: extendBody ensures content flows under the floating nav bar
          // so post grids and scroll views use the full screen height.
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: child,
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
              ? null
              : _BottomNav(
                  selectedIndex: _indexForLocation(context),
                  glass: themeController.glass,
                  onDestinationSelected: (index) {
                    final current = GoRouterState.of(context).uri.path;
                    final target = _routes[index];
                    if (current != target) context.go(target);
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
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Feed'),
    (icon: Icons.search_outlined, selectedIcon: Icons.search_rounded, label: 'Search'),
    (icon: Icons.favorite_outline_rounded, selectedIcon: Icons.favorite_rounded, label: 'Favorites'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Account'),
    (icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 76,
          child: GlassContainer(
            thickness: glass,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: Center(
                      child: _NavItem(
                        icon: _items[i].icon,
                        selectedIcon: _items[i].selectedIcon,
                        label: _items[i].label,
                        selected: i == selectedIndex,
                        color: theme.colorScheme.primary,
                        onTap: () => onDestinationSelected(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.28), blurRadius: 9, spreadRadius: -5)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: selected ? 24 : 21,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
