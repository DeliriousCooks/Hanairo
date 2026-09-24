import 'package:equatable/equatable.dart';

enum BooruSource {
  rule34xxx('rule34.xxx', 'R34'),
  e621('e621.net', 'E621'),
  gelbooru('gelbooru.com', 'Gelb'),
  paheal('rule34.paheal.net', 'Paheal'),
  danbooru('danbooru.donmai.us', 'Danb'),
  xbooru('xbooru.com', 'Xb');

  final String domain;
  final String shortName;
  const BooruSource(this.domain, this.shortName);
}

enum ContentRating { safe, questionable, explicit, unknown }

enum FileType { image, gif, video, webm, unknown }

enum PostStatus { active, deleted, pending }

class PostTag extends Equatable {
  final String name;
  final String category;
  final int? count;

  const PostTag({
    required this.name,
    required this.category,
    this.count,
  });

  @override
  List<Object?> get props => [name, category];

  String get displayName => name.replaceAll('_', ' ');
}

class Post extends Equatable {
  final String id;
  final BooruSource source;
  final String? thumbnailUrl;
  final String? previewUrl;
  final String? fileUrl;
  final String? sampleUrl;
  final int? width;
  final int? height;
  final int? previewWidth;
  final int? previewHeight;
  final int? sampleWidth;
  final int? sampleHeight;
  final FileType fileType;
  final ContentRating rating;
  final int score;
  final int? favoriteCount;
  final List<PostTag> tags;
  final String? md5;
  final int? fileSize;
  final String? sourceUrl;
  final DateTime? createdAt;
  final String? uploaderName;
  final int? uploaderId;
  final PostStatus status;
  final bool isFavorited;
  final String? description;
  final List<String>? pools;

  const Post({
    required this.id,
    required this.source,
    this.thumbnailUrl,
    this.previewUrl,
    this.fileUrl,
    this.sampleUrl,
    this.width,
    this.height,
    this.previewWidth,
    this.previewHeight,
    this.sampleWidth,
    this.sampleHeight,
    required this.fileType,
    required this.rating,
    required this.score,
    this.favoriteCount,
    required this.tags,
    this.md5,
    this.fileSize,
    this.sourceUrl,
    this.createdAt,
    this.uploaderName,
    this.uploaderId,
    required this.status,
    this.isFavorited = false,
    this.description,
    this.pools,
  });

  String get uniqueId => '${source.name}_$id';

  bool get isVideo => fileType == FileType.video || fileType == FileType.webm;
  bool get isGif => fileType == FileType.gif;
  bool get isImage => fileType == FileType.image;

  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Best URL for display (prefer sample over full for perf)
  String? get displayUrl => sampleUrl ?? fileUrl;

  /// Best URL for full quality
  String? get fullQualityUrl => fileUrl;

  List<String> get tagNames => tags.map((t) => t.name).toList();

  List<PostTag> tagsByCategory(String category) =>
      tags.where((t) => t.category == category).toList();

  Post copyWith({
    bool? isFavorited,
    int? score,
    int? favoriteCount,
  }) {
    return Post(
      id: id,
      source: source,
      thumbnailUrl: thumbnailUrl,
      previewUrl: previewUrl,
      fileUrl: fileUrl,
      sampleUrl: sampleUrl,
      width: width,
      height: height,
      previewWidth: previewWidth,
      previewHeight: previewHeight,
      sampleWidth: sampleWidth,
      sampleHeight: sampleHeight,
      fileType: fileType,
      rating: rating,
      score: score ?? this.score,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      tags: tags,
      md5: md5,
      fileSize: fileSize,
      sourceUrl: sourceUrl,
      createdAt: createdAt,
      uploaderName: uploaderName,
      uploaderId: uploaderId,
      status: status,
      isFavorited: isFavorited ?? this.isFavorited,
      description: description,
      pools: pools,
    );
  }

  @override
  List<Object?> get props => [uniqueId];
}

class SearchQuery extends Equatable {
  final List<String> tags;
  final List<BooruSource> sources;
  final ContentRating? ratingFilter;
  final int? minScore;
  final List<FileType>? fileTypeFilter;
  final int page;
  final int limit;

  const SearchQuery({
    required this.tags,
    required this.sources,
    this.ratingFilter,
    this.minScore,
    this.fileTypeFilter,
    this.page = 0,
    this.limit = 60,
  });

  String get tagString => tags.join(' ');

  SearchQuery copyWith({
    List<String>? tags,
    List<BooruSource>? sources,
    ContentRating? ratingFilter,
    int? minScore,
    List<FileType>? fileTypeFilter,
    int? page,
    int? limit,
  }) {
    return SearchQuery(
      tags: tags ?? this.tags,
      sources: sources ?? this.sources,
      ratingFilter: ratingFilter ?? this.ratingFilter,
      minScore: minScore ?? this.minScore,
      fileTypeFilter: fileTypeFilter ?? this.fileTypeFilter,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  List<Object?> get props => [tags, sources, ratingFilter, minScore, fileTypeFilter, page];
}
