import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/logger.dart';
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
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final posts = extra?['posts'] as List<Post>? ?? [];
        final index = extra?['index'] as int? ?? 0;
        return ViewerScreen(posts: posts, initialIndex: index);
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

class _ThemeWrapper extends StatefulWidget {
  @override
  State<_ThemeWrapper> createState() => _ThemeWrapperState();
}

class _ThemeWrapperState extends State<_ThemeWrapper> {
  bool _isDark = true;

  @override
  void initState() {
    super.initState();
    _isDark = _localRepo.isDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Booru Gallery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
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
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: child,
      bottomNavigationBar: _BottomNav(
        selectedIndex: _indexForLocation(context),
        onDestinationSelected: (index) {
          context.go(_routes[index]);
        },
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const _BottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.15),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
