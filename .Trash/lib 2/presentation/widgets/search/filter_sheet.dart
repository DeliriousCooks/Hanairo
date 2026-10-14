import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/post.dart';
import '../../blocs/search_bloc.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  ContentRating? _rating;
  int? _minScore;
  Set<FileType> _fileTypes = {};
  final _scoreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<SearchBloc>().state;
    _rating = state.ratingFilter;
    _minScore = state.minScore;
    _fileTypes = Set.from(state.fileTypeFilter ?? []);
    if (_minScore != null) _scoreCtrl.text = _minScore.toString();
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    HapticFeedback.lightImpact();
    context.read<SearchBloc>().add(SearchFilterChanged(
          ratingFilter: _rating,
          minScore: _minScore,
          fileTypeFilter: _fileTypes.isEmpty ? null : _fileTypes.toList(),
        ));
    Navigator.pop(context);
  }

  void _reset() {
    HapticFeedback.lightImpact();
    context.read<SearchBloc>().add(SearchFilterChanged());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Text('Filters', style: theme.textTheme.headlineMedium),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Rating ───────────────────────────────────────────────
                  Text('Rating', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _RatingChip(
                        label: 'All',
                        selected: _rating == null,
                        color: theme.colorScheme.onSurface,
                        onTap: () => setState(() => _rating = null),
                      ),
                      _RatingChip(
                        label: 'Safe',
                        selected: _rating == ContentRating.safe,
                        color: AppColors.ratingSafe,
                        onTap: () => setState(() => _rating = ContentRating.safe),
                      ),
                      _RatingChip(
                        label: 'Questionable',
                        selected: _rating == ContentRating.questionable,
                        color: AppColors.ratingQuestionable,
                        onTap: () =>
                            setState(() => _rating = ContentRating.questionable),
                      ),
                      _RatingChip(
                        label: 'Explicit',
                        selected: _rating == ContentRating.explicit,
                        color: AppColors.ratingExplicit,
                        onTap: () =>
                            setState(() => _rating = ContentRating.explicit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── File Type ────────────────────────────────────────────
                  Text('File Type', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _TypeChip(
                        label: 'Images',
                        icon: Icons.image_outlined,
                        selected: _fileTypes.contains(FileType.image),
                        onTap: () => setState(() {
                          if (!_fileTypes.remove(FileType.image)) {
                            _fileTypes.add(FileType.image);
                          }
                        }),
                      ),
                      _TypeChip(
                        label: 'GIFs',
                        icon: Icons.gif_box_outlined,
                        selected: _fileTypes.contains(FileType.gif),
                        onTap: () => setState(() {
                          if (!_fileTypes.remove(FileType.gif)) {
                            _fileTypes.add(FileType.gif);
                          }
                        }),
                      ),
                      _TypeChip(
                        label: 'Video',
                        icon: Icons.movie_outlined,
                        selected: _fileTypes.contains(FileType.video) ||
                            _fileTypes.contains(FileType.webm),
                        onTap: () => setState(() {
                          final hasVideo = _fileTypes.contains(FileType.video);
                          if (hasVideo) {
                            _fileTypes.remove(FileType.video);
                            _fileTypes.remove(FileType.webm);
                          } else {
                            _fileTypes.add(FileType.video);
                            _fileTypes.add(FileType.webm);
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ─── Min Score ────────────────────────────────────────────
                  Text('Minimum Score', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scoreCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 50',
                            prefixIcon: Icon(Icons.arrow_upward_rounded, size: 18),
                          ),
                          onChanged: (v) {
                            _minScore = int.tryParse(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...[-1, 0, 50, 200].map((v) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: GestureDetector(
                              onTap: () {
                                final val = v < 0 ? null : v;
                                setState(() {
                                  _minScore = val;
                                  _scoreCtrl.text = val?.toString() ?? '';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _minScore == (v < 0 ? null : v)
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  v < 0 ? 'Any' : '+$v',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _minScore == (v < 0 ? null : v)
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ─── Apply button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RatingChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.3),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : color.withOpacity(0.6),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
