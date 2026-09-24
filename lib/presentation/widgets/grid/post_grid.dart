import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';
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
    final isFavorite = context.read<LocalRepository>().isFavorite(post.uniqueId);

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
                  child: Material(
                    color: Colors.black.withOpacity(0.42),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: widget.onFavoriteTapped,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 17,
                          color: isFavorite ? const Color(0xFFFF82B2) : Colors.white,
                        ),
                      ),
                    ),
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
