import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import '../../domain/entities/post.dart';
import '../../core/utils/logger.dart';
import '../../core/tags/tag_translator.dart';

abstract class BooruDataSource {
  BooruSource get source;
  Future<List<Post>> search(SearchQuery query);
  Future<Post?> getPost(String id);
  Future<List<String>> getTagSuggestions(String prefix);
  Future<int?> getTagCount(String tag);
  Future<bool> login(String username, String credential);
  Future<bool> addFavorite(String postId);
  Future<bool> removeFavorite(String postId);
  Future<bool> vote(String postId, int score);
}

// ─── RULE34.XXX ──────────────────────────────────────────────────────────────

class Rule34xxxDataSource implements BooruDataSource {
  final Dio _dio;
  String? _userId;
  String? _apiKey;

  Rule34xxxDataSource()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.rule34.xxx',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent': 'BooruAggregator/1.0',
          },
        ));

  @override
  BooruSource get source => BooruSource.rule34xxx;

  @override
  Future<List<Post>> search(SearchQuery query) async {
    try {
      final tags = _buildTagString(query);
      final params = <String, dynamic>{
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'limit': query.limit,
        'pid': query.page,
        'json': 1,
      };

      if (_userId != null && _apiKey != null) {
        params['user_id'] = _userId;
        params['api_key'] = _apiKey;
      }

      final response = await _dio.get('/index.php', queryParameters: params);

      return _extractPostRows(response.data).map(_parsePost).toList();
    } catch (e) {
      AppLogger.error('Rule34xxx search error', e);
      rethrow;
    }
  }

  Post _parsePost(Map<String, dynamic> json) {
    final tagStr = json['tags'] as String? ?? '';
    final tags = tagStr.trim().split(' ').where((t) => t.isNotEmpty).map((t) {
      return PostTag(name: t, category: 'general');
    }).toList();

    final fileUrl = json['file_url'] as String? ?? '';
    final fileType = _detectFileType(fileUrl);

    return Post(
      id: json['id'].toString(),
      source: source,
      thumbnailUrl: json['preview_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      fileUrl: fileUrl,
      sampleUrl: json['sample_url'] as String?,
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      fileType: fileType,
      rating: _parseRating(json['rating'] as String? ?? 'e'),
      score: _toInt(json['score']) ?? 0,
      tags: tags,
      md5: json['md5'] as String?,
      fileSize: _toInt(json['file_size']),
      createdAt: _parseDate(json['change']?.toString()),
      status: PostStatus.active,
    );
  }

  String _buildTagString(SearchQuery query) {
    var tags = TagTranslator.translate(query.tags, BooruSource.rule34xxx);
    if (query.ratingFilter != null) {
      tags.add('rating:${_ratingToString(query.ratingFilter!)}');
    }
    if (query.minScore != null) {
      tags.add('score:>=${query.minScore}');
    }
    return tags.join(TagTranslator.separator(BooruSource.rule34xxx));
  }

  @override
  Future<List<String>> getTagSuggestions(String prefix) async {
    try {
      final params = <String, dynamic>{
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '${prefix.toLowerCase()}%',
        'limit': 20,
        'json': 1,
        'order': 'count',
      };
      if (_userId != null && _apiKey != null) {
        params['user_id'] = _userId;
        params['api_key'] = _apiKey;
      }
      final response = await _dio.get('/index.php', queryParameters: params);

      if (response.data == null) return [];
      final List<dynamic> data =
          response.data is List ? response.data : [response.data];
      return data.map((t) => t['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int?> getTagCount(String tag) async {
    try {
      final response = await _dio.get('/index.php', queryParameters: {
        'page': 'dapi', 's': 'tag', 'q': 'index',
        'name_pattern': canonicalizeTag(tag), 'limit': 20, 'json': 1,
      });
      final rows = response.data is List ? response.data as List : [response.data];
      for (final row in rows) {
        if (row is Map && row['name'] == canonicalizeTag(tag)) {
          return _toInt(row['count']);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final params = <String, dynamic>{
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'id': id,
        'json': 1,
      };
      if (_userId != null && _apiKey != null) {
        params['user_id'] = _userId;
        params['api_key'] = _apiKey;
      }
      final response = await _dio.get('/index.php', queryParameters: params);
      if (response.data == null) return null;
      final List<dynamic> data =
          response.data is List ? response.data : [response.data];
      if (data.isEmpty) return null;
      return _parsePost(data.first as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> login(String username, String credential) async {
    // rule34.xxx authenticates with (user_id, api_key), not (username, password).
    // The "username" parameter here is expected to be the numeric User ID shown
    // on the account's API Access Credentials page.
    _userId = username;
    _apiKey = credential;
    return true;
  }

  @override
  Future<bool> addFavorite(String postId) async => false;
  @override
  Future<bool> removeFavorite(String postId) async => false;
  @override
  Future<bool> vote(String postId, int score) async => false;
}

// ─── E621 ─────────────────────────────────────────────────────────────────────

class E621DataSource implements BooruDataSource {
  final Dio _dio;
  String? _username;
  String? _apiKey;

  E621DataSource()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://e621.net',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent': 'BooruAggregator/1.0 (contact@example.com)',
          },
        ));

  @override
  BooruSource get source => BooruSource.e621;

  void _setAuth() {
    if (_username != null && _apiKey != null) {
      _dio.options.headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$_username:$_apiKey'))}';
    }
  }

  @override
  Future<List<Post>> search(SearchQuery query) async {
    try {
      _setAuth();
      final tags = _buildTagString(query);
      final response = await _dio.get('/posts.json', queryParameters: {
        'tags': tags,
        'limit': query.limit,
        'page': query.page + 1,
      });

      final data = response.data as Map<String, dynamic>?;
      if (data == null) return [];

      final posts = data['posts'] as List<dynamic>? ?? [];
      return posts
          .map((p) => _parsePost(p as Map<String, dynamic>))
          .where((p) => p.fileUrl != null)
          .toList();
    } catch (e) {
      AppLogger.error('e621 search error', e);
      return [];
    }
  }

  Post _parsePost(Map<String, dynamic> json) {
    final file = json['file'] as Map<String, dynamic>? ?? {};
    final preview = json['preview'] as Map<String, dynamic>? ?? {};
    final sample = json['sample'] as Map<String, dynamic>? ?? {};
    final tagMap = json['tags'] as Map<String, dynamic>? ?? {};
    final score = json['score'] as Map<String, dynamic>? ?? {};
    final flags = json['flags'] as Map<String, dynamic>? ?? {};

    final List<PostTag> tags = [];
    tagMap.forEach((category, tagList) {
      if (tagList is List) {
        for (final tag in tagList) {
          tags.add(PostTag(name: tag as String, category: category));
        }
      }
    });

    final fileUrl = file['url'] as String?;
    final ext = file['ext'] as String? ?? '';
    final fileType = _extToFileType(ext);

    return Post(
      id: json['id'].toString(),
      source: source,
      thumbnailUrl: preview['url'] as String?,
      previewUrl: preview['url'] as String?,
      fileUrl: fileUrl,
      sampleUrl: (sample['has'] as bool? ?? false) ? sample['url'] as String? : fileUrl,
      width: _toInt(file['width']),
      height: _toInt(file['height']),
      previewWidth: _toInt(preview['width']),
      previewHeight: _toInt(preview['height']),
      sampleWidth: _toInt(sample['width']),
      sampleHeight: _toInt(sample['height']),
      fileType: fileType,
      rating: _parseE621Rating(json['rating'] as String? ?? 'e'),
      score: _toInt(score['total']) ?? 0,
      favoriteCount: _toInt(json['fav_count']),
      tags: tags,
      md5: file['md5'] as String?,
      fileSize: _toInt(file['size']),
      createdAt: _parseDate(json['created_at'] as String?),
      uploaderName: json['uploader_name'] as String?,
      description: json['description'] as String?,
      status: (flags['deleted'] as bool? ?? false)
          ? PostStatus.deleted
          : PostStatus.active,
      isFavorited: json['is_favorited'] as bool? ?? false,
    );
  }

  String _buildTagString(SearchQuery query) {
    var tags = TagTranslator.translate(query.tags, BooruSource.e621);
    if (query.ratingFilter != null) {
      tags.add('rating:${_e621RatingString(query.ratingFilter!)}');
    }
    if (query.minScore != null) {
      tags.add('score:>=${query.minScore}');
    }
    if (query.fileTypeFilter != null && query.fileTypeFilter!.isNotEmpty) {
      final types = query.fileTypeFilter!.map(_fileTypeToExt).join(',');
      tags.add('type:$types');
    }
    return tags.join(TagTranslator.separator(BooruSource.e621));
  }

  @override
  Future<List<String>> getTagSuggestions(String prefix) async {
    try {
      _setAuth();
      final response = await _dio.get('/tags.json', queryParameters: {
        'search[name_matches]': '${prefix}*',
        'search[order]': 'count',
        'limit': 20,
      });
      final data = response.data as List<dynamic>? ?? [];
      return data.map((t) => t['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int?> getTagCount(String tag) async {
    try {
      _setAuth();
      final response = await _dio.get('/tags.json', queryParameters: {
        'search[name_matches]': '${canonicalizeTag(tag)}*', 'limit': 20,
      });
      final rows = response.data as List<dynamic>? ?? [];
      for (final row in rows) {
        if (row is Map && row['name'] == canonicalizeTag(tag)) {
          return _toInt(row['post_count']);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      _setAuth();
      final response = await _dio.get('/posts/$id.json');
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      return _parsePost(data['post'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> login(String username, String credential) async {
    _username = username;
    _apiKey = credential;
    _setAuth();
    try {
      final response = await _dio.get('/users/$username.json');
      return response.statusCode == 200;
    } catch (e) {
      _username = null;
      _apiKey = null;
      return false;
    }
  }

  @override
  Future<bool> addFavorite(String postId) async {
    try {
      _setAuth();
      await _dio.post('/favorites.json', data: {'post_id': postId});
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> removeFavorite(String postId) async {
    try {
      _setAuth();
      await _dio.delete('/favorites/$postId.json');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> vote(String postId, int score) async {
    try {
      _setAuth();
      await _dio.post('/posts/$postId/votes.json', data: {'score': score});
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ─── GELBOORU ─────────────────────────────────────────────────────────────────

class GelbooruDataSource implements BooruDataSource {
  final Dio _dio;
  String? _userId;
  String? _apiKey;

  GelbooruDataSource()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://gelbooru.com',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'User-Agent': 'BooruAggregator/1.0'},
        ));

  @override
  BooruSource get source => BooruSource.gelbooru;

  @override
  Future<List<Post>> search(SearchQuery query) async {
    try {
      final tags = _buildTagString(query);
      final params = <String, dynamic>{
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'tags': tags,
        'limit': query.limit,
        'pid': query.page,
        'json': 1,
      };
      if (_userId != null && _apiKey != null) {
        params['user_id'] = _userId;
        params['api_key'] = _apiKey;
      }

      final response = await _dio.get('/index.php', queryParameters: params);
      return _extractPostRows(response.data).map(_parsePost).toList();
    } catch (e) {
      AppLogger.error('Gelbooru search error', e);
      rethrow;
    }
  }

  Post _parsePost(Map<String, dynamic> json) {
    final tagStr = json['tags'] as String? ?? '';
    final tags = tagStr.trim().split(' ').where((t) => t.isNotEmpty).map((t) {
      return PostTag(name: t, category: 'general');
    }).toList();

    final fileUrl = json['file_url'] as String? ?? '';
    return Post(
      id: json['id'].toString(),
      source: source,
      thumbnailUrl: json['preview_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      fileUrl: fileUrl,
      sampleUrl: json['sample_url'] as String?,
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      fileType: _detectFileType(fileUrl),
      rating: _parseRating(json['rating'] as String? ?? 'e'),
      score: _toInt(json['score']) ?? 0,
      tags: tags,
      md5: json['md5'] as String?,
      fileSize: _toInt(json['file_size']),
      createdAt: _parseDate(json['change']?.toString()),
      status: PostStatus.active,
    );
  }

  String _buildTagString(SearchQuery query) {
    var tags = TagTranslator.translate(query.tags, BooruSource.gelbooru);
    if (query.ratingFilter != null) {
      tags.add('rating:${_ratingToString(query.ratingFilter!)}');
    }
    return tags.join(TagTranslator.separator(BooruSource.gelbooru));
  }

  @override
  Future<List<String>> getTagSuggestions(String prefix) async {
    try {
      final response = await _dio.get('/index.php', queryParameters: {
        'page': 'dapi',
        's': 'tag',
        'q': 'index',
        'name_pattern': '${prefix}%',
        'limit': 20,
        'json': 1,
        'orderby': 'count',
      });
      final data = response.data;
      if (data == null) return [];
      if (data is Map && data['tag'] != null) {
        final tags = data['tag'] as List<dynamic>;
        return tags.map((t) => t['name'] as String).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int?> getTagCount(String tag) async {
    try {
      final response = await _dio.get('/index.php', queryParameters: {
        'page': 'dapi', 's': 'tag', 'q': 'index',
        'name_pattern': canonicalizeTag(tag), 'limit': 20, 'json': 1,
      });
      final body = response.data;
      final rows = body is Map ? (body['tag'] as List<dynamic>? ?? []) : <dynamic>[];
      for (final row in rows) {
        if (row is Map && row['name'] == canonicalizeTag(tag)) {
          return _toInt(row['count']);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response = await _dio.get('/index.php', queryParameters: {
        'page': 'dapi',
        's': 'post',
        'q': 'index',
        'id': id,
        'json': 1,
      });
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      final posts = data['post'] as List<dynamic>? ?? [];
      if (posts.isEmpty) return null;
      return _parsePost(posts.first as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> login(String username, String credential) async {
    _userId = username;
    _apiKey = credential;
    return true;
  }

  @override
  Future<bool> addFavorite(String postId) async => false;
  @override
  Future<bool> removeFavorite(String postId) async => false;
  @override
  Future<bool> vote(String postId, int score) async => false;
}

// ─── PAHEAL ───────────────────────────────────────────────────────────────────

class PahealDataSource implements BooruDataSource {
  final Dio _dio;

  PahealDataSource()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://rule34.paheal.net',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'User-Agent': 'BooruAggregator/1.0'},
        ));

  @override
  BooruSource get source => BooruSource.paheal;

  @override
  Future<List<Post>> search(SearchQuery query) async {
    try {
      final tagString = TagTranslator.translateForSource(query.tags, BooruSource.paheal);
      final page = query.page + 1;
      final response = await _dio.get(
        '/api/danbooru/find_posts/index.xml',
        queryParameters: {
          'tags': tagString,
          'limit': query.limit,
          'page': page,
        },
      );

      final xmlStr = response.data as String? ?? '';
      if (xmlStr.isEmpty) return [];

      final doc = XmlDocument.parse(xmlStr);
      final posts = doc.findAllElements('post');
      return posts.map(_parseXmlPost).toList();
    } catch (e) {
      AppLogger.error('Paheal search error', e);
      rethrow;
    }
  }

  Post _parseXmlPost(XmlElement el) {
    final fileUrl = el.getAttribute('file_url') ?? '';
    final tagStr = el.getAttribute('tags') ?? '';
    final tags = tagStr.trim().split(' ').where((t) => t.isNotEmpty).map((t) {
      return PostTag(name: t, category: 'general');
    }).toList();

    return Post(
      id: el.getAttribute('id') ?? '',
      source: source,
      thumbnailUrl: el.getAttribute('preview_url'),
      fileUrl: fileUrl,
      sampleUrl: el.getAttribute('sample_url'),
      width: int.tryParse(el.getAttribute('width') ?? ''),
      height: int.tryParse(el.getAttribute('height') ?? ''),
      fileType: _detectFileType(fileUrl),
      rating: ContentRating.explicit,
      score: int.tryParse(el.getAttribute('score') ?? '') ?? 0,
      tags: tags,
      md5: el.getAttribute('md5'),
      status: PostStatus.active,
    );
  }

  @override
  Future<List<String>> getTagSuggestions(String prefix) async {
    try {
      final response = await _dio.get(
        '/api/danbooru/find_tags/index.xml',
        queryParameters: {'name': '${prefix}%', 'limit': 20},
      );
      final xmlStr = response.data as String? ?? '';
      if (xmlStr.isEmpty) return [];
      final doc = XmlDocument.parse(xmlStr);
      return doc.findAllElements('tag').map((e) => e.getAttribute('name') ?? '').toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<int?> getTagCount(String tag) async {
    try {
      final response = await _dio.get('/api/danbooru/find_tags/index.xml',
          queryParameters: {'name': canonicalizeTag(tag), 'limit': 20});
      final xmlStr = response.data as String? ?? '';
      if (xmlStr.isEmpty) return null;
      final doc = XmlDocument.parse(xmlStr);
      for (final element in doc.findAllElements('tag')) {
        if (element.getAttribute('name') == canonicalizeTag(tag)) {
          return int.tryParse(element.getAttribute('count') ?? '');
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Post?> getPost(String id) async => null;
  @override
  Future<bool> login(String username, String credential) async => false;
  @override
  Future<bool> addFavorite(String postId) async => false;
  @override
  Future<bool> removeFavorite(String postId) async => false;
  @override
  Future<bool> vote(String postId, int score) async => false;
}

// ─── SHARED HELPERS ───────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractPostRows(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
  if (body is Map) {
    final rows = body['post'] ?? body['posts'];
    if (rows is List) {
      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    if (rows is Map) return [Map<String, dynamic>.from(rows)];
    if (body.containsKey('id') && body.containsKey('file_url')) {
      return [Map<String, dynamic>.from(body)];
    }
    return const [];
  }
  if (body is String) {
    final trimmed = body.trimLeft();
    try {
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return _extractPostRows(jsonDecode(body));
      }
      if (trimmed.startsWith('<')) {
        final document = XmlDocument.parse(body);
        return document.findAllElements('post').map((element) => <String, dynamic>{
              for (final attribute in element.attributes)
                attribute.name.local: attribute.value,
            }).toList();
      }
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value.toString());
}

FileType _detectFileType(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.webm')) return FileType.webm;
  if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return FileType.video;
  if (lower.endsWith('.gif')) return FileType.gif;
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return FileType.image;
  }
  return FileType.unknown;
}

FileType _extToFileType(String ext) {
  switch (ext.toLowerCase()) {
    case 'webm':
      return FileType.webm;
    case 'mp4':
    case 'mov':
      return FileType.video;
    case 'gif':
      return FileType.gif;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'webp':
      return FileType.image;
    default:
      return FileType.unknown;
  }
}

String _fileTypeToExt(FileType ft) {
  switch (ft) {
    case FileType.video:
      return 'mp4';
    case FileType.webm:
      return 'webm';
    case FileType.gif:
      return 'gif';
    default:
      return 'jpg';
  }
}

ContentRating _parseRating(String r) {
  switch (r.toLowerCase()) {
    case 's':
    case 'safe':
      return ContentRating.safe;
    case 'q':
    case 'questionable':
      return ContentRating.questionable;
    case 'e':
    case 'explicit':
      return ContentRating.explicit;
    default:
      return ContentRating.unknown;
  }
}

ContentRating _parseE621Rating(String r) {
  switch (r.toLowerCase()) {
    case 's':
      return ContentRating.safe;
    case 'q':
      return ContentRating.questionable;
    case 'e':
      return ContentRating.explicit;
    default:
      return ContentRating.unknown;
  }
}

String _ratingToString(ContentRating r) {
  switch (r) {
    case ContentRating.safe:
      return 'safe';
    case ContentRating.questionable:
      return 'questionable';
    case ContentRating.explicit:
      return 'explicit';
    default:
      return 'explicit';
  }
}

String _e621RatingString(ContentRating r) {
  switch (r) {
    case ContentRating.safe:
      return 's';
    case ContentRating.questionable:
      return 'q';
    case ContentRating.explicit:
      return 'e';
    default:
      return 'e';
  }
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  // Unix timestamp
  final ts = int.tryParse(value);
  if (ts != null) {
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }
  return DateTime.tryParse(value);
}
