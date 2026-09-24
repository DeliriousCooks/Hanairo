import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../main.dart' show ThemeScope;
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/page_background.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, Map<String, String>> _credentials = const {};

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final credentials = await context.read<LocalRepository>().loadCredentials();
    if (mounted) setState(() => _credentials = credentials);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<LocalRepository>();
    final favorites = repo.getFavorites();
    final history = repo.getSearchHistory();
    final top = MediaQuery.of(context).padding.top;

    return PageBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 22, 20, 20),
              child: Row(
                children: [
                  Text('Account', style: theme.textTheme.headlineLarge),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success.withOpacity(0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 13, color: AppColors.success),
                      const SizedBox(width: 5),
                      Text('PRIVATE SPACE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.success,
                            letterSpacing: 0.7,
                          )),
                    ]),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                thickness: _glassThickness(context),
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              const Color(0xFF547EEC),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.28),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset('assets/images/booruwave_mark.svg'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Gallery', style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 4),
                            Text('Your art, all in one place',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant),
                    ]),
                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white.withOpacity(0.10)),
                    const SizedBox(height: 15),
                    Row(children: [
                      _Stat(value: '${favorites.length}', label: 'FAVORITES'),
                      _Stat(value: '${_credentials.length}', label: 'CONNECTED'),
                      _Stat(value: '${history.length}', label: 'SEARCHES'),
                    ]),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: _SectionTitle(title: 'Your collection'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MenuCard(children: [
                _AccountTile(
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFFFF7FAF),
                  title: 'My Favorites',
                  subtitle: '${favorites.length} saved posts',
                  onTap: () => context.go('/favorites'),
                ),
                _AccountTile(
                  icon: Icons.history_rounded,
                  color: const Color(0xFF76C8E7),
                  title: 'Search History',
                  subtitle: history.isEmpty
                      ? 'Your recent searches will appear here'
                      : '${history.length} recent searches',
                  onTap: () => context.go('/search'),
                ),
                _AccountTile(
                  icon: Icons.block_rounded,
                  color: const Color(0xFFFFA86B),
                  title: 'Blocked Tags',
                  subtitle: repo.getBlacklist().isEmpty
                      ? 'No tags blocked'
                      : '${repo.getBlacklist().length} tags blocked',
                  onTap: () => context.go('/settings'),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: _SectionTitle(
              title: 'Connected booru sites',
              action: TextButton(
                onPressed: () => context.go('/settings'),
                child: const Text('Manage'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MenuCard(
                children: BooruSource.values.take(4).map((source) {
                  final connected = _credentials.containsKey(source.name);
                  return _AccountTile(
                    icon: Icons.public_rounded,
                    color: _sourceColor(source),
                    title: source.domain,
                    subtitle: connected ? 'Connected' : 'Tap to connect your account',
                    status: connected,
                    onTap: () => context.push('/auth/${source.name}'),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
              child: Text(
                'Your favorites and search history are stored on this device. Account credentials are kept in secure storage.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.72),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  GlassThickness _glassThickness(BuildContext context) =>
      ThemeScope.of(context).glass;

  Color _sourceColor(BooruSource source) {
    switch (source) {
      case BooruSource.rule34xxx:
        return const Color(0xFF8875FF);
      case BooruSource.e621:
        return const Color(0xFF5FCFC4);
      case BooruSource.gelbooru:
        return const Color(0xFFFF83A8);
      case BooruSource.paheal:
        return const Color(0xFFFFC66F);
      default:
        return const Color(0xFF78A8FF);
    }
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 3),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.7,
            )),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 23, 16, 10),
      child: Row(children: [
        Text(title, style: theme.textTheme.titleLarge),
        const Spacer(),
        if (action != null) action!,
      ]),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.58),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
                ),
              ),
          ],
        ]),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool? status;

  const _AccountTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 2),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: status == true ? AppColors.success : theme.colorScheme.onSurfaceVariant,
          )),
      trailing: Icon(Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
