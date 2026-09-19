import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/post.dart';
import '../../../data/repositories/local_repository.dart';
import '../../blocs/search_bloc.dart';

class ViewerScreen extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const ViewerScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = true;
  bool _showDetails = false;
  late AnimationController _uiController;
  late Animation<double> _uiAnim;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _uiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _uiAnim = CurvedAnimation(parent: _uiController, curve: Curves.easeInOut);
    _uiController.value = 1.0;

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Warm the cache for the starting image and its immediate neighbors so
    // the very first swipe doesn't have to wait on a cold network fetch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAround(_currentIndex);
    });
  }

  /// Precaches the images immediately before/after [index] (and index
  /// itself) so swiping to them is instant instead of showing a spinner
  /// while a fresh network fetch + decode happens. This is the standard
  /// fix for "swiping feels laggy" in PageView-based image galleries -
  /// without it, every single swipe pays the full network+decode cost.
  void _precacheAround(int index) {
    for (final i in [index, index - 1, index + 1]) {
      if (i < 0 || i >= widget.posts.length) continue;
      final post = widget.posts[i];
      if (post.isVideo) continue; // videos aren't precached as images
      final url = post.displayUrl ?? post.thumbnailUrl;
      if (url == null || url.isEmpty) continue;
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {
        // Best-effort only; a failed precache just falls back to the
        // normal in-place loading spinner for that page.
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiController.forward();
    } else {
      _uiController.reverse();
      _showDetails = false;
    }
  }

  Post get _currentPost => widget.posts[_currentIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // ─── Media Gallery ─────────────────────────────────────────────────
          GestureDetector(
            onTap: _toggleUI,
            child: _MediaGallery(
              posts: widget.posts,
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _showDetails = false;
                });
                _precacheAround(index);
              },
            ),
          ),

          // ─── Top Bar (back + info) ─────────────────────────────────────────
          FadeTransition(
            opacity: _uiAnim,
            child: _TopBar(
              post: _currentPost,
              currentIndex: _currentIndex,
              total: widget.posts.length,
              onBack: () {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                context.pop();
              },
              onInfo: () {
                setState(() => _showDetails = !_showDetails);
              },
            ),
          ),

          // ─── Bottom Actions ────────────────────────────────────────────────
          FadeTransition(
            opacity: _uiAnim,
            child: Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomActions(
                post: _currentPost,
                onDetailsToggle: () {
                  setState(() => _showDetails = !_showDetails);
                },
              ),
            ),
          ),

          // ─── Details Panel (slide up) ──────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            bottom: _showDetails ? 0 : -500,
            left: 0,
            right: 0,
            child: _DetailsPanel(post: _currentPost),
          ),
        ],
      ),
    );
  }
}

// ─── Media Gallery ────────────────────────────────────────────────────────────

class _MediaGallery extends StatelessWidget {
  final List<Post> posts;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const _MediaGallery({
    required this.posts,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      pageController: pageController,
      itemCount: posts.length,
      onPageChanged: onPageChanged,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      builder: (context, index) {
        final post = posts[index];

        if (post.isVideo || post.isGif) {
          return PhotoViewGalleryPageOptions.customChild(
            child: _VideoPlayerWidget(post: post),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.5,
          );
        }

        final url = post.displayUrl ?? post.thumbnailUrl ?? '';
        return PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(url),
          minScale: PhotoViewComputedScale.contained * 0.8,
          maxScale: PhotoViewComputedScale.covered * 3.0,
          heroAttributes: PhotoViewHeroAttributes(tag: post.uniqueId),
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 52, color: Colors.white30),
          ),
        );
      },
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

// ─── Video Player ─────────────────────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  final Post post;
  const _VideoPlayerWidget({required this.post});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _vpController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.post.fileUrl ?? widget.post.sampleUrl;
    if (url == null) return;

    _vpController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _vpController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _vpController!,
      autoPlay: true,
      looping: true,
      aspectRatio: widget.post.aspectRatio,
      allowFullScreen: false,
      showControls: true,
    );

    if (mounted) setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _vpController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _chewieController == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _vpController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Post post;
  final int currentIndex;
  final int total;
  final VoidCallback onBack;
  final VoidCallback onInfo;

  const _TopBar({
    required this.post,
    required this.currentIndex,
    required this.total,
    required this.onBack,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          8,
          MediaQuery.of(context).padding.top + 8,
          8,
          20,
        ),
        child: Row(
          children: [
            // Back button
            _ViewerButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 8),
            // Post counter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentIndex + 1} / $total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            // Source badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                post.source.shortName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ViewerButton(icon: Icons.info_outline_rounded, onTap: onInfo),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Actions ───────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final Post post;
  final VoidCallback onDetailsToggle;

  const _BottomActions({
    required this.post,
    required this.onDetailsToggle,
  });

  @override
  Widget build(BuildContext context) {
    final localRepo = context.read<LocalRepository>();
    final isFav = localRepo.isFavorite(post.uniqueId);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        24,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Row(
        children: [
          // Favorite
          _ActionButton(
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
            label: 'Save',
            color: isFav ? AppColors.error : Colors.white,
            onTap: () {
              HapticFeedback.mediumImpact();
              context.read<SearchBloc>().add(PostFavoriteToggled(post));
            },
          ),
          const SizedBox(width: 16),
          // Details
          _ActionButton(
            icon: Icons.layers_outlined,
            label: 'Details',
            onTap: onDetailsToggle,
          ),
          const Spacer(),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  post.score >= 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: post.score >= 0 ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  post.score.abs().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Details Panel ────────────────────────────────────────────────────────────

class _DetailsPanel extends StatelessWidget {
  final Post post;
  const _DetailsPanel({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.darkBorder.withOpacity(0.5)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta info
                  _MetaRow(post: post),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.darkDivider),
                  const SizedBox(height: 16),
                  // Tags
                  _TagsSection(post: post),
                  const SizedBox(height: 16),
                  if (post.description?.isNotEmpty ?? false) ...[
                    const Divider(height: 1, color: AppColors.darkDivider),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Post post;
  const _MetaRow({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Post #${post.id}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              if (post.uploaderName != null)
                Text(
                  'by ${post.uploaderName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MetaBadge(
                    label: '${post.width ?? '?'}×${post.height ?? '?'}',
                    icon: Icons.aspect_ratio_rounded,
                  ),
                  const SizedBox(width: 8),
                  _MetaBadge(
                    label: post.fileType.name.toUpperCase(),
                    icon: Icons.insert_drive_file_outlined,
                  ),
                  const SizedBox(width: 8),
                  _RatingBadge(rating: post.rating),
                ],
              ),
            ],
          ),
        ),
        if (post.fileSize != null)
          Text(
            _formatFileSize(post.fileSize!),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.darkBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final ContentRating rating;
  const _RatingBadge({required this.rating});

  Color get _color {
    switch (rating) {
      case ContentRating.safe:
        return AppColors.ratingSafe;
      case ContentRating.questionable:
        return AppColors.ratingQuestionable;
      case ContentRating.explicit:
        return AppColors.ratingExplicit;
      default:
        return AppColors.textTertiary;
    }
  }

  String get _label {
    switch (rating) {
      case ContentRating.safe:
        return 'Safe';
      case ContentRating.questionable:
        return 'Questionable';
      case ContentRating.explicit:
        return 'Explicit';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagsSection extends StatelessWidget {
  final Post post;
  const _TagsSection({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();

    // Group tags by category
    final tagsByCategory = <String, List<PostTag>>{};
    for (final tag in post.tags) {
      tagsByCategory.putIfAbsent(tag.category, () => []).add(tag);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags (${post.tags.length})',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...tagsByCategory.entries.map((entry) {
          final color =
              ext?.tagColors[entry.key] ?? AppColors.textSecondary;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.value.map((tag) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // Search this tag
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: color.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        tag.displayName,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }),
      ],
    );
  }
}

class _ViewerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ViewerButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
