import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/post.dart';

class PostGridSliver extends StatelessWidget {
  final List<Post> posts;
  final void Function(Post post, int index) onPostTapped;
  final int columns;

  const PostGridSliver({
    super.key,
    required this.posts,
    required this.onPostTapped,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final post = posts[index];
            return PostTile(
              // Stable key (not just index) so Flutter correctly preserves
              // each tile's element/render state across rebuilds instead
              // of potentially reassociating it with a different post if
              // the list ever reorders (dedup, blacklist filtering, a
              // fresh list instance from pagination) - this is part of
              // what caused visible jumping/flicker when new pages loaded.
              key: ValueKey('${post.source.name}_${post.id}'),
              post: post,
              onTap: () => onPostTapped(post, index),
            );
          },
          childCount: posts.length,
        ),
      ),
    );
  }
}

class PostTile extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;

  const PostTile({
    super.key,
    required this.post,
    required this.onTap,
  });

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
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
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Thumbnail ─────────────────────────────────────────────
              _ThumbnailImage(post: post, ext: ext),

              // ─── Overlay badges ────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _PostOverlay(post: post),
              ),

              // ─── Media type badge ──────────────────────────────────────
              if (post.isVideo || post.isGif)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _MediaTypeBadge(post: post),
                ),

              // ─── Source badge ──────────────────────────────────────────
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
    final url = post.thumbnailUrl ?? post.previewUrl ?? post.fileUrl;

    if (url == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, size: 24),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
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
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
          stops: [0.0, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
      child: Row(
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
              post.score.abs().toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
          ],
          // Rating indicator
          _RatingDot(rating: post.rating),
        ],
      ),
    );
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
          BoxShadow(color: _color.withOpacity(0.5), blurRadius: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            post.isVideo ? Icons.play_circle_filled : Icons.gif_box_outlined,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            post.isVideo ? 'VIDEO' : 'GIF',
            style: const TextStyle(
              fontSize: 9,
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
      default:
        return const Color(0xFF7C8FFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.85),
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
