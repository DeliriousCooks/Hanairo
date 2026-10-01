import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/theme_settings.dart';
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
import 'presentation/widgets/common/liquid_glass_surface.dart';

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
          pageBuilder: (context, state) => _tabTransitionPage(
            key: state.pageKey,
            child: const FeedScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return _tabTransitionPage(
              key: state.pageKey,
              child: SearchScreen(initialQuery: query),
            );
          },
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) => _tabTransitionPage(
            key: state.pageKey,
            child: const FavoritesScreen(),
          ),
        ),
        GoRoute(
          path: '/account',
          pageBuilder: (context, state) => _tabTransitionPage(
            key: state.pageKey,
            child: const AccountScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _tabTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
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

CustomTransitionPage<void> _tabTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    transitionDuration: const Duration(milliseconds: 210),
    reverseTransitionDuration: const Duration(milliseconds: 170),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.018),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

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
          body: _SwipeableTabBody(
            onSwipe: (direction) => _navigateBySwipe(context, direction),
            child: child,
          ),
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: MediaQuery.of(context).viewInsets.bottom > 0
              ? null
              : _BottomNav(
                  selectedIndex: _indexForLocation(context),
                  glass: themeController.glass,
                  onDestinationSelected: (index) {
                    final current = GoRouterState.of(context).uri.path;
                    final target = _routes[index];
                    if (current != target) {
                      HapticFeedback.selectionClick();
                      context.go(target);
                    }
                  },
                ),
        );
      },
    );
  }

  void _navigateBySwipe(BuildContext context, int direction) {
    final nextIndex = _indexForLocation(context) + direction;
    if (nextIndex < 0 || nextIndex >= _routes.length) return;

    final target = _routes[nextIndex];
    if (GoRouterState.of(context).uri.path == target) return;

    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    HapticFeedback.selectionClick();
    context.go(target);
  }
}

class _SwipeableTabBody extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onSwipe;

  const _SwipeableTabBody({required this.child, required this.onSwipe});

  @override
  State<_SwipeableTabBody> createState() => _SwipeableTabBodyState();
}

class _SwipeableTabBodyState extends State<_SwipeableTabBody> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragCancel: () => _dragDistance = 0,
      onHorizontalDragEnd: (details) {
        final distance = _dragDistance;
        final velocity = details.primaryVelocity ?? 0;
        _dragDistance = 0;
        if (distance.abs() < 72 && velocity.abs() < 300) return;
        final direction = distance.abs() >= 72
            ? (distance < 0 ? 1 : -1)
            : (velocity < 0 ? 1 : -1);
        widget.onSwipe(direction);
      },
      child: widget.child,
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
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: LiquidGlassSurface(
          sigma: glass.sigma.clamp(12.0, 18.0).toDouble(),
          highContrast: true,
          borderRadius: BorderRadius.circular(27),
          child: SizedBox(
             height: 76,
             child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
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
    final isDark = theme.brightness == Brightness.dark;
    final activeBackground = isDark
        ? color.withOpacity(0.94)
        : color.withOpacity(0.14);
    final activeForeground = isDark ? Colors.white : color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            scale: selected ? 1 : 0.96,
            child: AnimatedContainer(
              // Every selected tab gets the same compact footprint. This
              // prevents the highlight from filling its whole flex slot.
              width: 62,
              height: 56,
              alignment: Alignment.center,
              duration: const Duration(milliseconds: 190),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected ? activeBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: selected
                    ? Border.all(color: color.withOpacity(isDark ? 0.22 : 0.18))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? selectedIcon : icon,
                    size: selected ? 21 : 20,
                    color: selected
                        ? activeForeground
                        : theme.colorScheme.onSurface.withOpacity(0.82),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: selected
                            ? activeForeground
                            : theme.colorScheme.onSurface.withOpacity(0.82),
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
