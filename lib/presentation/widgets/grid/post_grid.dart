import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/media_saver.dart';
import '../../../data/repositories/local_repository.dart';
import '../../../domain/entities/post.dart';

class PostGridSliver extends StatelessWidget {
  final List<Post> posts;
  final void Function(Post post, int index) onPostTapped;
  final int columns;
  final ValueChanged<Post>? onFavoriteTapped;

  const PostGridSliver({
    super.key,
    required this.posts,
    required this.onPostTapped,
    this.columns = 3,
    this.onFavoriteTapped,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            return PostTile(
              // Stable key prevents layout jumps when list rebuilds
              key: ValueKey('${post.source.name}_${post.id}'),
              post: post,
              onTap: () => onPostTapped(post, index),
              onFavoriteTapped: onFavoriteTapped == null
                  ? null
                  : () => onFavoriteTapped!(post),
            );
          },
          childCount: posts.length,
          // Disable addRepaintBoundaries to avoid unnecessary layer allocation
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

/// A roomy, single-post feed mode. Images use the original file URL and are
/// contained in the media window so the post is visible without cropping.
class SinglePostFeedSliver extends StatelessWidget {
  final List<Post> posts;
  final ValueChanged<Post> onFavoriteTapped;
  final void Function(Post post, int index) onPostTapped;

  const SinglePostFeedSliver({
    super.key,
    required this.posts,
    required this.onFavoriteTapped,
    required this.onPostTapped,
  });

  @override
  Widget build(BuildContext context) => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _SinglePostFeedCard(
            key: ValueKey('single_${posts[index].uniqueId}'),
            post: posts[index],
            onFavorite: () => onFavoriteTapped(posts[index]),
            onTap: () => onPostTapped(posts[index], index),
          ),
          childCount: posts.length,
        ),
      );
}

class _SinglePostFeedCard extends StatefulWidget {
  final Post post;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _SinglePostFeedCard({
    super.key,
    required this.post,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  State<_SinglePostFeedCard> createState() => _SinglePostFeedCardState();
}

class _SinglePostFeedCardState extends State<_SinglePostFeedCard> {
  Timer? _heartTimer;
  bool _showHeart = false;
  bool _saving = false;

  @override
  void dispose() {
    _heartTimer?.cancel();
    super.dispose();
  }

  void _favorite() {
    HapticFeedback.mediumImpact();
    widget.onFavorite();
    _heartTimer?.cancel();
    setState(() => _showHeart = true);
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  Future<void> _export() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      await savePostMedia(widget.post);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(widget.post.isVideo
              ? 'Video saved to Photos'
              : 'Image saved to Photos'),
          duration: const Duration(seconds: 2),
        ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Could not save this media: $error'),
          duration: const Duration(seconds: 3),
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = context.read<LocalRepository>();
    final mediaHeight = (MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).top -
            MediaQuery.paddingOf(context).bottom -
            78 - // floating tab bar
            8 - // tab bar bottom inset
            220) // post header, tags, and card spacing
        .clamp(200.0, 560.0)
        .toDouble();
    final previewTags = widget.post.tags.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withOpacity(0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.tag_rounded,
                        color: theme.colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.source.shortName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        Text('Post #${widget.post.id}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            )),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: local.favoritesRevision,
                    builder: (context, _, __) {
                      final saved = local.isFavorite(widget.post.uniqueId);
                      return IconButton.filledTonal(
                        tooltip: saved ? 'Remove favorite' : 'Add favorite',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onFavorite,
                        icon: Icon(saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded),
                        color: saved
                            ? const Color(0xFFFF78AD)
                            : theme.colorScheme.onSurfaceVariant,
                      );
                    },
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: _favorite,
              onLongPress: _export,
              child: SizedBox(
                height: mediaHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF08080A)
                          : theme.colorScheme.surfaceContainerHighest,
                      child: _SingleFeedMedia(post: widget.post),
                    ),
                    if (_saving)
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: _FeedHintPill(
                          icon: Icons.downloading_rounded,
                          label: 'Saving…',
                        ),
                      )
                    else
                      const Positioned(
                        top: 12,
                        left: 12,
                        child: _FeedHintPill(
                          icon: Icons.touch_app_rounded,
                          label: 'Double tap to favorite · hold to export',
                        ),
                      ),
                    Center(
                      child: AnimatedScale(
                        scale: _showHeart ? 1 : 0.45,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showHeart ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFF7EAE),
                            size: 88,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 16)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 17, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text('${widget.post.score}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      if (widget.post.isVideo || widget.post.isGif)
                        const _FeedHintPill(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Video',
                        ),
                    ],
                  ),
                  if (previewTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: previewTags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer.withOpacity(0.66),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tag.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedHintPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeedHintPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 5),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            )),
      ]),
    );
  }
}

class _SingleFeedMedia extends StatefulWidget {
  final Post post;
  const _SingleFeedMedia({required this.post});

  @override
  State<_SingleFeedMedia> createState() => _SingleFeedMediaState();
}

class _SingleFeedMediaState extends State<_SingleFeedMedia> {
  int _urlIndex = 0;
  VideoPlayerController? _video;
  String? _videoError;
  bool _muted = true;

  List<String> get _urls => [
        widget.post.fileUrl,
        widget.post.sampleUrl,
        widget.post.previewUrl,
        widget.post.thumbnailUrl,
      ].whereType<String>().where((url) => url.isNotEmpty).toSet().toList();

  @override
  void initState() {
    super.initState();
    if (widget.post.isVideo) _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final url = widget.post.fileUrl ?? widget.post.sampleUrl;
    if (url == null || url.isEmpty) {
      setState(() => _videoError = 'Video URL unavailable');
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoError = 'Could not load video');
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  void _tryNextImageUrl() {
    if (_urlIndex >= _urls.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _urlIndex < _urls.length - 1) {
        setState(() => _urlIndex++);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.isVideo) return _buildVideo();
    final urls = _urls;
    if (urls.isEmpty || _urlIndex >= urls.length) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 42),
      );
    }
    return CachedNetworkImage(
      imageUrl: urls[_urlIndex],
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) {
        _tryNextImageUrl();
        return const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 42),
        );
      },
    );
  }

  Widget _buildVideo() {
    final controller = _video;
    if (_videoError != null) {
      return Center(
        child: Text(_videoError!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _VideoControl(
            tooltip: _muted ? 'Unmute video' : 'Mute video',
            icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            onPressed: () async {
              final next = !_muted;
              await controller.setVolume(next ? 0 : 1);
              if (mounted) setState(() => _muted = next);
            },
          ),
        ),
        Center(
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => _VideoControl(
              tooltip: value.isPlaying ? 'Pause video' : 'Play video',
              icon: value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
              large: true,
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 8,
          child: VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Color(0xFF9D83FF),
              bufferedColor: Colors.white38,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoControl extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool large;

  const _VideoControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black.withOpacity(0.64),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: large ? 32 : 20),
          constraints: BoxConstraints.tight(Size.square(large ? 58 : 44)),
        ),
      );
}

class PostTile extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTapped;

  const PostTile({
    super.key,
    required this.post,
    required this.onTap,
    this.onFavoriteTapped,
  });

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final post = widget.post;
    final localRepository = context.read<LocalRepository>();

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Background color while loading ─────────────────────────
              Container(color: theme.colorScheme.surfaceContainerHighest),

              // ─── Thumbnail ───────────────────────────────────────────────
              _ThumbnailImage(post: post, ext: ext),

              // ─── Bottom gradient + badges ────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _PostOverlay(post: post),
              ),

              // ─── Media type badge ────────────────────────────────────────
              if (post.isVideo || post.isGif)
                Positioned(
                  top: widget.onFavoriteTapped != null ? 42 : 6,
                  right: 6,
                  child: _MediaTypeBadge(post: post),
                ),

              if (widget.onFavoriteTapped != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ValueListenableBuilder<int>(
                    valueListenable: localRepository.favoritesRevision,
                    builder: (context, _, __) {
                      final isFavorite =
                          localRepository.isFavorite(post.uniqueId);
                      return Material(
                        color: Colors.black.withOpacity(0.48),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: widget.onFavoriteTapped,
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(scale: animation, child: child),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                key: ValueKey(isFavorite),
                                size: 17,
                                color: isFavorite
                                    ? const Color(0xFFFF82B2)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ─── Source badge ────────────────────────────────────────────
              Positioned(
                top: 6,
                left: 6,
                child: _SourceBadge(source: post.source),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  final Post post;
  final AppThemeExtension? ext;

  const _ThumbnailImage({required this.post, required this.ext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = post.thumbnailUrl ?? post.previewUrl ?? post.sampleUrl ?? post.fileUrl;

    if (url == null || url.isEmpty) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // Use memCacheWidth to limit decoded size and speed up display
      memCacheWidth: 400,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: ext?.shimmerBase ?? AppColors.darkCard,
        highlightColor: ext?.shimmerHighlight ?? AppColors.darkCardElevated,
        child: Container(color: Colors.white),
      ),
      errorWidget: (context, url, error) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class _PostOverlay extends StatelessWidget {
  final Post post;
  const _PostOverlay({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB3000000), Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.tags.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: post.tags.take(2).map((tag) => Container(
                constraints: const BoxConstraints(maxWidth: 96),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tag.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              )).toList(),
            ),
            const SizedBox(height: 5),
          ],
          Row(
            children: [
          // Score
          if (post.score != 0) ...[
            Icon(
              post.score > 0
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 10,
              color: post.score > 0 ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 2),
            Text(
              _formatScore(post.score.abs()),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
          ] else
            const Spacer(),
          // Rating dot
          _RatingDot(rating: post.rating),
            ],
          ),
        ],
      ),
    );
  }

  String _formatScore(int score) {
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
    return score.toString();
  }
}

class _RatingDot extends StatelessWidget {
  final ContentRating rating;
  const _RatingDot({required this.rating});

  Color get _color {
    switch (rating) {
      case ContentRating.safe:
        return AppColors.ratingSafe;
      case ContentRating.questionable:
        return AppColors.ratingQuestionable;
      case ContentRating.explicit:
        return AppColors.ratingExplicit;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _color.withOpacity(0.6), blurRadius: 4),
        ],
      ),
    );
  }
}

class _MediaTypeBadge extends StatelessWidget {
  final Post post;
  const _MediaTypeBadge({required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            post.isVideo ? Icons.play_circle_filled : Icons.gif_box_outlined,
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            post.isVideo ? 'VID' : 'GIF',
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final BooruSource source;
  const _SourceBadge({required this.source});

  Color get _color {
    switch (source) {
      case BooruSource.rule34xxx:
        return const Color(0xFF7C6FFF);
      case BooruSource.e621:
        return const Color(0xFF4ECDC4);
      case BooruSource.gelbooru:
        return const Color(0xFFFF7CA0);
      case BooruSource.paheal:
        return const Color(0xFFFFCC7C);
      case BooruSource.danbooru:
        return const Color(0xFFFF9D4F);
      default:
        return const Color(0xFF7C8FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        source.shortName,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
