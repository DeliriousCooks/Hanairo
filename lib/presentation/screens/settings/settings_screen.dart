import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_settings.dart';
import '../../../main.dart' show ThemeScope;
import '../../widgets/common/page_background.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _safeMode;
  late int _gridColumns;
  late List<String> _blacklist;

  @override
  void initState() {
    super.initState();
    _syncFromRepo();
  }

  void _syncFromRepo() {
    final repo = context.read<LocalRepository>();
    _safeMode = repo.isSafeMode();
    _gridColumns = repo.getGridColumns();
    _blacklist = repo.getBlacklist();
  }

  // Called when returning to this screen from auth sub-routes
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-read persisted values every time this screen becomes active
    final repo = context.read<LocalRepository>();
    final safe = repo.isSafeMode();
    final cols = repo.getGridColumns();
    final bl = repo.getBlacklist();
    if (safe != _safeMode || cols != _gridColumns || bl.length != _blacklist.length) {
      setState(() {
        _safeMode = safe;
        _gridColumns = cols;
        _blacklist = bl;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = context.read<LocalRepository>();
    final themeController = ThemeScope.of(context);

    return PageBackground(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverToBoxAdapter(
            child: _SettingsHeader(),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ─── Appearance ───────────────────────────────────────────────
              _SectionHeader(title: 'Appearance'),

              // Dark mode toggle
              _SettingsTile(
                title: 'Dark Mode',
                subtitle: 'Default dark, recommended',
                leading: _SettingsIcon(
                  icon: themeController.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: themeController.isDark
                      ? const Color(0xFF7C6FFF)
                      : const Color(0xFFFFCC7C),
                ),
                trailing: Switch(
                  value: themeController.isDark,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    themeController.setDark(v);
                  },
                ),
              ),

              // Theme preset
              _SettingsTile(
                title: 'Theme Preset',
                subtitle: themeController.preset.label,
                leading: _SettingsIcon(
                  icon: Icons.palette_outlined,
                  color: theme.colorScheme.primary,
                ),
                trailing: null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: ThemePreset.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final preset = ThemePreset.values[i];
                        final selected = preset == themeController.preset;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            themeController.setPreset(preset);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(
                                  colors: preset.gradientDark),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.white.withOpacity(0.15),
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              preset.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Accent color
              _SettingsTile(
                title: 'Accent Color',
                subtitle: themeController.accent.label,
                leading: _SettingsIcon(
                  icon: Icons.color_lens_outlined,
                  color: themeController.accent.color,
                ),
                trailing: null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AccentColor.values.map((accent) {
                      final selected = accent == themeController.accent;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          themeController.setAccent(accent);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: accent.color.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Liquid glass intensity
              _SettingsTile(
                title: 'Liquid Glass',
                subtitle: '${themeController.glass.label} blur intensity',
                leading: _SettingsIcon(
                  icon: Icons.water_drop_outlined,
                  color: const Color(0xFF4ECDC4),
                ),
                trailing: null,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Row(
                    children: GlassThickness.values.map((g) {
                      final selected = g == themeController.glass;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            themeController.setGlass(g);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(0.3),
                                width: selected ? 1.5 : 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              g.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Grid columns
              _SettingsTile(
                title: 'Grid Columns',
                subtitle: '$_gridColumns columns',
                leading: _SettingsIcon(
                  icon: Icons.grid_view_rounded,
                  color: const Color(0xFF6FCF7A),
                ),
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
                                fontWeight: FontWeight.w700,
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

              // ─── Content ──────────────────────────────────────────────────
              _SectionHeader(title: 'Content'),

              _SettingsTile(
                title: 'Safe Mode',
                subtitle: 'Show only safe-rated content',
                leading: _SettingsIcon(
                  icon: Icons.shield_outlined,
                  color: AppColors.ratingSafe,
                ),
                trailing: Switch(
                  value: _safeMode,
                  onChanged: (v) async {
                    HapticFeedback.selectionClick();
                    await repo.setSafeMode(v);
                    setState(() => _safeMode = v);
                  },
                ),
              ),

              _SettingsTile(
                title: 'Tag Blacklist',
                subtitle: _blacklist.isEmpty
                    ? 'No tags blocked'
                    : '${_blacklist.length} tag${_blacklist.length == 1 ? '' : 's'} blocked',
                leading: _SettingsIcon(
                  icon: Icons.block_rounded,
                  color: AppColors.ratingExplicit,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showBlacklist(context, repo),
              ),

              _SettingsTile(
                title: 'Search History',
                subtitle: 'Clear your recent searches',
                leading: _SettingsIcon(
                  icon: Icons.history_rounded,
                  color: const Color(0xFFFF9D4F),
                ),
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

              // ─── Sources & Auth ───────────────────────────────────────────
              _SectionHeader(title: 'Sources & Accounts'),
              ...BooruSource.values.take(4).map((source) => _SettingsTile(
                    title: source.domain,
                    subtitle: 'Tap to configure account',
                    leading: _SourceDot(source: source),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.push('/auth/${source.name}'),
                  )),

              // ─── About ────────────────────────────────────────────────────
              _SectionHeader(title: 'About'),
              _SettingsTile(
                title: 'BooruWave',
                subtitle: 'Version 1.0.0',
                leading: _SettingsIcon(
                  icon: Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                trailing: const SizedBox.shrink(),
              ),

              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  void _showBlacklist(BuildContext context, LocalRepository repo) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Container(
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.65,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
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
                          prefixIcon: Icon(Icons.block_rounded, size: 18),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (tag) async {
                          if (tag.trim().isEmpty) return;
                          await repo.addToBlacklist(tag.trim());
                          controller.clear();
                          final updated = repo.getBlacklist();
                          setModal(() {});
                          setState(() => _blacklist = updated);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final tag = controller.text.trim();
                        if (tag.isEmpty) return;
                        await repo.addToBlacklist(tag);
                        controller.clear();
                        final updated = repo.getBlacklist();
                        setModal(() {});
                        setState(() => _blacklist = updated);
                      },
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: _blacklist.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No blacklisted tags',
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _blacklist.length,
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            title: Text(_blacklist[i]),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () async {
                                await repo.removeFromBlacklist(_blacklist[i]);
                                final updated = repo.getBlacklist();
                                setModal(() {});
                                setState(() => _blacklist = updated);
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Settings Header ──────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 20,
        20,
        8,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.6)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Settings',
            style: theme.textTheme.headlineLarge,
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────

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
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withOpacity(0.6),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Widget? child;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.leading,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: leading,
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
    if (child == null) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child!,
        ),
      ],
    );
  }
}

// ─── Settings Icon ────────────────────────────────────────────────────────

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

// ─── Source Dot ───────────────────────────────────────────────────────────

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
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(9),
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
