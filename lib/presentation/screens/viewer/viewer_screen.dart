import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _currentIndex = widget.posts.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.posts.length - 1);

    _pageController = PageController(
      initialPage: _currentIndex,
      keepPage: false, // don't keep stale page offset across rebuilds
    );

    _uiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _uiAnim = CurvedAnimation(parent: _uiController, curve: Curves.easeInOut);
    _uiController.value = 1.0;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Warm cache for the starting image and neighbors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheAround(_currentIndex);
    });
  }

  void _precacheAround(int index) {
    for (final i in [index - 1, index, index + 1]) {
      if (i < 0 || i >= widget.posts.length) continue;
      final post = widget.posts[i];
      if (post.isVideo) continue;
      // Use displayUrl preferably (full res), then sample, then thumbnail
      final url = post.fileUrl ?? post.sampleUrl ?? post.previewUrl ?? post.thumbnailUrl;
      if (url == null || url.isEmpty) continue;
      precacheImage(
        CachedNetworkImageProvider(url),
        context,
      ).catchError((_) {/* best-effort */});
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _uiController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    if (_showUI) {
      _uiController.forward();
    } else {
      _uiController.reverse();
      if (_showDetails) setState(() => _showDetails = false);
    }
  }

  Post get _currentPost => widget.posts[_currentIndex];

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF090B16),
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.image_not_supported_outlined,
                  color: Colors.white54, size: 42),
              const SizedBox(height: 12),
              const Text('This post is no longer available',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.pop(), child: const Text('Go back')),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF090B16),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
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
                    onInfo: () => setState(() => _showDetails = !_showDetails),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _currentPost.isVideo ? null : _toggleUI,
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) > 420) {
                        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                        context.pop();
                      }
                    },
                    child: ColoredBox(
                      color: const Color(0xFF090B16),
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
                  ),
                ),
                FadeTransition(
                  opacity: _uiAnim,
                  child: _BottomActions(
                    post: _currentPost,
                    onDetailsToggle: () =>
                        setState(() => _showDetails = !_showDetails),
                  ),
                ),
              ],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _showDetails ? 0 : -700,
              left: 0,
              right: 0,
              child: _DetailsPanel(
                post: _currentPost,
                onDismiss: () => setState(() => _showDetails = false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Media Gallery (fixed grey screen bug) ────────────────────────────────

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
    return PageView.builder(
      controller: pageController,
      itemCount: posts.length,
      onPageChanged: onPageChanged,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final post = posts[index];
        return post.isVideo
            ? _VideoPlayerWidget(key: ValueKey(post.uniqueId), post: post)
            : _ViewerImagePage(key: ValueKey(post.uniqueId), post: post);
      },
    );
  }
}

class _ViewerImagePage extends StatefulWidget {
  final Post post;
  const _ViewerImagePage({super.key, required this.post});

  @override
  State<_ViewerImagePage> createState() => _ViewerImagePageState();
}

class _ViewerImagePageState extends State<_ViewerImagePage> {
  int _urlIndex = 0;

  List<String> get _urls => [
        widget.post.fileUrl,
        widget.post.sampleUrl,
        widget.post.previewUrl,
        widget.post.thumbnailUrl,
      ].whereType<String>().where((url) => url.isNotEmpty).toSet().toList();

  void _tryNextUrl() {
    if (mounted && _urlIndex < _urls.length - 1) {
      setState(() => _urlIndex++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty || _urlIndex >= urls.length) {
      return const _ViewerImageError();
    }
    final size = MediaQuery.sizeOf(context);
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: urls[_urlIndex],
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 140),
        placeholder: (context, _) => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF9D8BFF),
            ),
          ),
        ),
        errorWidget: (context, _, __) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryNextUrl());
          return const _ViewerImageError();
        },
      ),
    );
  }
}

class _ViewerImageError extends StatelessWidget {
  const _ViewerImageError();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.broken_image_outlined, size: 52, color: Colors.white38),
          SizedBox(height: 12),
          Text('Image unavailable', style: TextStyle(color: Colors.white60)),
        ]),
      );
}

// ─── Video Player ─────────────────────────────────────────────────────────

class _VideoPlayerWidget extends StatefulWidget {
  final Post post;
  const _VideoPlayerWidget({super.key, required this.post});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _vpController;
  bool _initialized = false;
  bool _muted = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.post.fileUrl ?? widget.post.sampleUrl;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _error = 'No video URL available');
      return;
    }

    try {
      _vpController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _vpController!.initialize();
      await _vpController!.setLooping(true);
      await _vpController!.setVolume(0);
      await _vpController!.play();

      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load video');
    }
  }

  @override
  void dispose() {
    _vpController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded,
                size: 52, color: Colors.white30),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }
    if (!_initialized || _vpController == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _vpController!.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_vpController!),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x99070A15), Colors.transparent],
                  ),
                ),
                child: VideoProgressIndicator(
                  _vpController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF9D83FF),
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black.withOpacity(0.64),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: _muted ? 'Unmute video' : 'Mute video',
                  onPressed: () async {
                    final nextMuted = !_muted;
                    await _vpController!.setVolume(nextMuted ? 0 : 1);
                    if (mounted) setState(() => _muted = nextMuted);
                  },
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _vpController!,
                builder: (context, value, _) => Material(
                  color: Colors.black.withOpacity(0.55),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: value.isPlaying ? 'Pause video' : 'Play video',
                    onPressed: () => value.isPlaying
                        ? _vpController!.pause()
                        : _vpController!.play(),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────

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
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          10,
          MediaQuery.of(context).padding.top + 8,
          10,
          20,
        ),
        child: Row(
          children: [
            _ViewerButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack,
            ),
            const SizedBox(width: 8),
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
            // Source label
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
    );
  }
}

// ─── Bottom Actions ───────────────────────────────────────────────────────

String _cleanBooruDescription(String value) => value
    .replaceAll(RegExp(r'\[\s*from\s+source\s*\]', caseSensitive: false), '')
    .replaceAll(RegExp(r'\[/?(?:i|b|u|s|quote|spoiler)\]', caseSensitive: false), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _sourcePostUrl(Post post) {
  if (post.sourceUrl?.isNotEmpty ?? false) return post.sourceUrl!;
  final id = Uri.encodeComponent(post.id);
  switch (post.source) {
    case BooruSource.e621:
      return 'https://e621.net/posts/$id';
    case BooruSource.rule34xxx:
      return 'https://rule34.xxx/index.php?page=post&s=view&id=$id';
    case BooruSource.gelbooru:
      return 'https://gelbooru.com/index.php?page=post&s=view&id=$id';
    case BooruSource.paheal:
      return 'https://rule34.paheal.net/post/view/$id';
    case BooruSource.danbooru:
      return 'https://danbooru.donmai.us/posts/$id';
    case BooruSource.xbooru:
      return 'https://xbooru.com/index.php?page=post&s=view&id=$id';
  }
}

Future<void> _savePostMedia(BuildContext context, Post post) async {
  final url = post.fileUrl ?? post.sampleUrl ?? post.previewUrl;
  if (url == null || url.isEmpty) throw StateError('No media URL is available');

  final uri = Uri.parse(url);
  final pathName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
  final extension = pathName.contains('.')
      ? pathName.split('.').last.toLowerCase()
      : (post.isVideo ? 'mp4' : 'jpg');
  final temp = await getTemporaryDirectory();
  final inputPath = '${temp.path}/booruwave-${post.id}.$extension';
  await Dio().download(
    url,
    inputPath,
    options: Options(receiveTimeout: const Duration(minutes: 3)),
  );

  var pathToSave = inputPath;
  if (post.isVideo && extension == 'webm') {
    final mp4Path = '${temp.path}/booruwave-${post.id}.mp4';
    final encoder = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    var session = await FFmpegKit.execute(
      '-y -i "$inputPath" -c:v $encoder -c:a aac -movflags +faststart "$mp4Path"',
    );
    var returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      session = await FFmpegKit.execute(
        '-y -i "$inputPath" -c:v mpeg4 -c:a aac -movflags +faststart "$mp4Path"',
      );
      returnCode = await session.getReturnCode();
    }
    final converted = File(mp4Path);
    if (!ReturnCode.isSuccess(returnCode) || !await converted.exists() || await converted.length() == 0) {
      throw StateError('Could not convert this WebM video to MP4');
    }
    pathToSave = mp4Path;
  }

  final result = await ImageGallerySaver.saveFile(pathToSave);
  if (result is Map && result['isSuccess'] != true && result['success'] != true) {
    throw StateError('The photo library did not accept this file');
  }
}

Future<void> _openSource(BuildContext context, Post post) async {
  final uri = Uri.tryParse(_sourcePostUrl(post));
  if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the source post')),
    );
  }
}

Future<void> _sharePost(BuildContext context, Post post) async {
  final link = _sourcePostUrl(post);
  final mediaUrl = post.fileUrl ?? post.sampleUrl ?? post.previewUrl;
  try {
    if (mediaUrl == null || post.isVideo) {
      await Share.share(link, subject: 'BooruWave post');
      return;
    }
    final response = await Dio().get<List<int>>(
      mediaUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) throw StateError('Empty media response');
    final lowerUrl = mediaUrl.toLowerCase();
    final mime = lowerUrl.contains('.png') ? 'image/png'
        : lowerUrl.contains('.webp') ? 'image/webp'
        : lowerUrl.contains('.gif') ? 'image/gif' : 'image/jpeg';
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: mime,
      name: 'booruwave-${post.id}.${mime.split('/').last}',
    );
    await Share.shareXFiles([file], text: link, subject: 'BooruWave post');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not prepare this post to share')),
      );
    }
  }
}

class _BottomActions extends StatelessWidget {
  final Post post;
  final VoidCallback onDetailsToggle;

  const _BottomActions({
    required this.post,
    required this.onDetailsToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 13),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xE51A1D35), Color(0xE5141B2D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x669C88FF)),
              boxShadow: const [
                BoxShadow(color: Color(0x332D55D8), blurRadius: 20, spreadRadius: -8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8A73FF), Color(0xFF4D8FFF)],
                      ),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.uploaderName ?? post.source.domain,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${post.source.shortName}  ·  Post #${post.id}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (post.score != 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.arrow_upward_rounded,
                          color: Color(0xFF87D7BA), size: 15),
                      const SizedBox(width: 3),
                      Text('${post.score}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ]),
                ]),
                if (post.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(
                    _cleanBooruDescription(post.description!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: post.tags.take(4).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E7BFF).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text('#${tag.displayName}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SaveAction(post: post),
              _DownloadAction(post: post),
              _ActionButton(
                icon: Icons.open_in_browser_rounded,
                label: 'Source',
                onTap: () => _openSource(context, post),
              ),
              _ActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: () => _sharePost(context, post),
              ),
              _ActionButton(
                icon: Icons.tag_rounded,
                label: 'Tags',
                onTap: onDetailsToggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadAction extends StatefulWidget {
  final Post post;
  const _DownloadAction({required this.post});

  @override
  State<_DownloadAction> createState() => _DownloadActionState();
}

class _DownloadActionState extends State<_DownloadAction> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _savePostMedia(context, widget.post);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(widget.post.isVideo ? 'Video saved to Photos' : 'Image saved to Photos'),
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
  Widget build(BuildContext context) => _ActionButton(
        icon: _saving ? Icons.downloading_rounded : Icons.download_rounded,
        label: _saving ? 'Saving' : 'Photos',
        onTap: _save,
      );
}

class _SaveAction extends StatelessWidget {
  final Post post;
  const _SaveAction({required this.post});

  @override
  Widget build(BuildContext context) {
    final localRepository = context.read<LocalRepository>();
    return ValueListenableBuilder<int>(
      valueListenable: localRepository.favoritesRevision,
      builder: (context, _, __) {
        final saved = localRepository.isFavorite(post.uniqueId);
        return _ActionButton(
          icon: saved ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          label: saved ? 'Saved' : 'Save',
          color: saved ? const Color(0xFFFF78AD) : Colors.white,
          onTap: () {
            HapticFeedback.mediumImpact();
            context.read<SearchBloc>().add(PostFavoriteToggled(post));
          },
        );
      },
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
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color == Colors.white ? Colors.white70 : color.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Details Panel ────────────────────────────────────────────────────────

class _DetailsPanel extends StatelessWidget {
  final Post post;
  final VoidCallback onDismiss;
  const _DetailsPanel({required this.post, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) onDismiss();
      },
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.darkBorder.withOpacity(0.4)),
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
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaRow(post: post),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.darkDivider),
                  const SizedBox(height: 16),
                  _TagsSection(post: post),
                  if (post.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
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
                      _cleanBooruDescription(post.description!),
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
              if (post.uploaderName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'by ${post.uploaderName}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaBadge(
                    label: '${post.width ?? '?'}×${post.height ?? '?'}',
                    icon: Icons.aspect_ratio_rounded,
                  ),
                  _MetaBadge(
                    label: post.fileType.name.toUpperCase(),
                    icon: Icons.insert_drive_file_outlined,
                  ),
                  _RatingBadge(rating: post.rating),
                  if (post.fileSize != null)
                    _MetaBadge(
                      label: _formatFileSize(post.fileSize!),
                      icon: Icons.storage_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
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
        return 'Q';
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

    if (tagsByCategory.isEmpty) {
      return Text(
        'No tags',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
      );
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
          final color = ext?.tagColors[entry.key] ?? AppColors.textSecondary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    color: color.withOpacity(0.6),
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
                        // Navigate to search with this tag
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
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
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
