import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/post.dart';

/// Downloads a post at its best available quality and saves it to Photos.
/// WebM clips are converted to MP4 first so they can be played by iOS Photos.
Future<void> savePostMedia(Post post) async {
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
    if (returnCode?.isValueSuccess() != true) {
      session = await FFmpegKit.execute(
        '-y -i "$inputPath" -c:v mpeg4 -c:a aac -movflags +faststart "$mp4Path"',
      );
      returnCode = await session.getReturnCode();
    }
    final converted = File(mp4Path);
    if (returnCode?.isValueSuccess() != true ||
        !await converted.exists() ||
        await converted.length() == 0) {
      throw StateError('Could not convert this WebM video to MP4');
    }
    pathToSave = mp4Path;
  }

  final result = await ImageGallerySaver.saveFile(pathToSave);
  if (result is Map && result['isSuccess'] != true && result['success'] != true) {
    throw StateError('The photo library did not accept this file');
  }
}
