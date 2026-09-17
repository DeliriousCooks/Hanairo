import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _darkMode;
  late bool _safeMode;
  late int _gridColumns;
  late List<String> _blacklist;

  @override
  void initState() {
    super.initState();
    final repo = context.read<LocalRepository>();
    _darkMode = repo.isDarkMode();
    _safeMode = repo.isSafeMode();
    _gridColumns = repo.getGridColumns();
    _blacklist = repo.getBlacklist();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<LocalRepository>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar.large(
          title: const Text('Settings'),
          backgroundColor: theme.scaffoldBackgroundColor,
          pinned: true,
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            // ─── Appearance ───────────────────────────────────────────────────
            _SectionHeader(title: 'Appearance'),
            _SettingsTile(
              title: 'Dark Mode',
              subtitle: 'Default dark, recommended',
              trailing: Switch(
                value: _darkMode,
                onChanged: (v) async {
                  await repo.setDarkMode(v);
                  setState(() => _darkMode = v);
                },
              ),
            ),
            _SettingsTile(
              title: 'Grid Columns',
              subtitle: 'Currently $_gridColumns columns',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [2, 3, 4].map((c) {
                  final sel = c == _gridColumns;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        await repo.setGridColumns(c);
                        setState(() => _gridColumns = c);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: sel
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$c',
                            style: TextStyle(
                              color: sel
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ─── Content ──────────────────────────────────────────────────────
            _SectionHeader(title: 'Content'),
            _SettingsTile(
              title: 'Safe Mode',
              subtitle: 'Show only safe-rated content',
              trailing: Switch(
                value: _safeMode,
                onChanged: (v) async {
                  await repo.setSafeMode(v);
                  setState(() => _safeMode = v);
                },
              ),
            ),
            _SettingsTile(
              title: 'Tag Blacklist',
              subtitle: '${_blacklist.length} tags blocked',
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _showBlacklist(context, repo),
            ),
            _SettingsTile(
              title: 'Search History',
              subtitle: 'Clear your recent searches',
              trailing: TextButton(
                onPressed: () async {
                  await repo.clearSearchHistory();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search history cleared')),
                    );
                  }
                },
                child: const Text('Clear'),
              ),
            ),

            // ─── Sources & Auth ───────────────────────────────────────────────
            _SectionHeader(title: 'Sources & Accounts'),
            ...BooruSource.values.take(4).map((source) => _SettingsTile(
                  title: source.domain,
                  subtitle: 'Tap to configure account',
                  leading: _SourceDot(source: source),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => context.go('/auth/${source.name}'),
                )),

            // ─── About ────────────────────────────────────────────────────────
            _SectionHeader(title: 'About'),
            _SettingsTile(
              title: 'Version',
              subtitle: '1.0.0',
              trailing: const SizedBox.shrink(),
            ),
            _SettingsTile(
              title: 'Bundle ID',
              subtitle: 'app.coral4330.carrot5939',
              trailing: const SizedBox.shrink(),
            ),

            const SizedBox(height: 100),
          ]),
        ),
      ],
    );
  }

  void _showBlacklist(BuildContext context, LocalRepository repo) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tag Blacklist',
                    style: Theme.of(ctx).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'Add tag to blacklist...',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final tag = controller.text.trim();
                        if (tag.isEmpty) return;
                        await repo.addToBlacklist(tag);
                        controller.clear();
                        setModal(() => _blacklist = repo.getBlacklist());
                        setState(() => _blacklist = repo.getBlacklist());
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _blacklist.isEmpty
                      ? const Center(
                          child: Text('No blacklisted tags'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _blacklist.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(_blacklist[i]),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () async {
                                await repo.removeFromBlacklist(_blacklist[i]);
                                setModal(
                                    () => _blacklist = repo.getBlacklist());
                                setState(
                                    () => _blacklist = repo.getBlacklist());
                              },
                            ),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: leading,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SourceDot extends StatelessWidget {
  final BooruSource source;
  const _SourceDot({required this.source});

  Color get _color {
    switch (source) {
      case BooruSource.rule34xxx:
        return AppColors.primary;
      case BooruSource.e621:
        return AppColors.secondary;
      case BooruSource.gelbooru:
        return const Color(0xFFFF7CA0);
      case BooruSource.paheal:
        return const Color(0xFFFFCC7C);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          source.shortName,
          style: TextStyle(
            color: _color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
