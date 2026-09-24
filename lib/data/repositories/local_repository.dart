import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/post.dart';

class LocalRepository {
  static const _favoritesBox = 'favorites';
  static const _historyBox = 'search_history';
  static const _blacklistBox = 'blacklist';
  static const _settingsBox = 'settings';
  static const _credentialsKey = 'booru_credentials';

  late Box<String> _favorites;
  late Box<String> _history;
  late Box<String> _blacklist;
  late Box<dynamic> _settings;
  final _secureStorage = const FlutterSecureStorage();
  final ValueNotifier<int> favoritesRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> favoriteTagsRevision = ValueNotifier<int>(0);

  Future<void> init() async {
    await Hive.initFlutter();
    _favorites = await Hive.openBox<String>(_favoritesBox);
    _history = await Hive.openBox<String>(_historyBox);
    _blacklist = await Hive.openBox<String>(_blacklistBox);
    _settings = await Hive.openBox<dynamic>(_settingsBox);
  }

  // ─── Favorites ──────────────────────────────────────────────────────────────

  Future<void> addFavorite(Post post) async {
    final json = jsonEncode(_postToMap(post));
    await _favorites.put(post.uniqueId, json);
    favoritesRevision.value++;
  }

  Future<void> removeFavorite(String uniqueId) async {
    await _favorites.delete(uniqueId);
    favoritesRevision.value++;
  }

  bool isFavorite(String uniqueId) => _favorites.containsKey(uniqueId);

  List<Post> getFavorites() {
    return _favorites.values
        .map((json) {
          try {
            return _postFromMap(jsonDecode(json) as Map<String, dynamic>);
          } catch (e) {
            return null;
          }
        })
        .whereType<Post>()
        .toList()
        .reversed
        .toList();
  }

  // ─── Search History ──────────────────────────────────────────────────────────

  Future<void> addSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    // Remove if exists (to re-add at top)
    final existing = _history.keys
        .where((k) => _history.get(k) == query)
        .toList();
    for (final k in existing) {
      await _history.delete(k);
    }
    // Keep max 50 history entries
    if (_history.length >= 50) {
      await _history.delete(_history.keys.first);
    }
    await _history.put(DateTime.now().millisecondsSinceEpoch.toString(), query);
  }

  List<String> getSearchHistory() {
    final entries = _history.toMap().entries.toList();
    entries.sort((a, b) => b.key.toString().compareTo(a.key.toString()));
    return entries.map((e) => e.value as String).take(20).toList();
  }

  Future<void> clearSearchHistory() async => _history.clear();

  Future<void> removeHistoryEntry(String query) async {
    final keys = _history.keys.where((k) => _history.get(k) == query).toList();
    for (final k in keys) {
      await _history.delete(k);
    }
  }

  // ─── Favorite Tags ──────────────────────────────────────────────────────────

  List<String> getFavoriteTags() {
    final raw = getSetting<String>('favorite_tags', '');
    if (raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  bool isFavoriteTag(String tag) =>
      getFavoriteTags().contains(_normalizeFavoriteTag(tag));

  Future<void> toggleFavoriteTag(String tag) async {
    final normalized = _normalizeFavoriteTag(tag);
    if (normalized.isEmpty) return;
    final tags = getFavoriteTags();
    if (tags.contains(normalized)) {
      tags.remove(normalized);
    } else {
      tags.insert(0, normalized);
      if (tags.length > 30) tags.removeLast();
    }
    await setSetting<String>('favorite_tags', jsonEncode(tags));
    favoriteTagsRevision.value++;
  }

  String _normalizeFavoriteTag(String tag) =>
      tag.trim().replaceAll(RegExp(r'\s+'), '_');

  // ─── Blacklist ───────────────────────────────────────────────────────────────

  Future<void> addToBlacklist(String tag) async {
    await _blacklist.put(tag, tag);
  }

  Future<void> removeFromBlacklist(String tag) async {
    await _blacklist.delete(tag);
  }

  List<String> getBlacklist() => _blacklist.values.toList();

  bool isBlacklisted(Post post) {
    final blacklist = getBlacklist();
    if (blacklist.isEmpty) return false;
    return post.tagNames.any((tag) => blacklist.contains(tag));
  }

  // ─── Settings ────────────────────────────────────────────────────────────────

  T getSetting<T>(String key, T defaultValue) {
    return _settings.get(key, defaultValue: defaultValue) as T;
  }

  Future<void> setSetting<T>(String key, T value) async {
    await _settings.put(key, value);
  }

  // Active sources
  List<String> getActiveSources() {
    final json = getSetting<String>('active_sources', '');
    if (json.isEmpty) {
      return [BooruSource.rule34xxx.name, BooruSource.e621.name];
    }
    return (jsonDecode(json) as List).cast<String>();
  }

  Future<void> setActiveSources(List<BooruSource> sources) async {
    await setSetting('active_sources', jsonEncode(sources.map((s) => s.name).toList()));
  }

  // Grid columns
  int getGridColumns() => getSetting<int>('grid_columns', 3);
  Future<void> setGridColumns(int cols) => setSetting('grid_columns', cols);

  // Theme
  bool isDarkMode() => getSetting<bool>('dark_mode', true);
  Future<void> setDarkMode(bool value) => setSetting('dark_mode', value);

  // Accent color (stored as the AccentColor enum's name, e.g. "violet")
  String getAccentColorName() => getSetting<String>('accent_color', 'violet');
  Future<void> setAccentColorName(String value) => setSetting('accent_color', value);

  // Liquid Glass thickness (stored as the GlassThickness enum's name)
  String getGlassThicknessName() => getSetting<String>('glass_thickness', 'regular');
  Future<void> setGlassThicknessName(String value) => setSetting('glass_thickness', value);

  // Theme preset / wallpaper (stored as the ThemePreset enum's name)
  String getThemePresetName() => getSetting<String>('theme_preset', 'defaultPreset');
  Future<void> setThemePresetName(String value) => setSetting('theme_preset', value);

  // Rating filter
  String getRatingFilter() => getSetting<String>('rating_filter', 'explicit');
  Future<void> setRatingFilter(String value) => setSetting('rating_filter', value);

  // Safe mode
  bool isSafeMode() => getSetting<bool>('safe_mode', false);
  Future<void> setSafeMode(bool value) => setSetting('safe_mode', value);

  // ─── Credentials ─────────────────────────────────────────────────────────────

  Future<void> saveCredentials(Map<String, Map<String, String>> creds) async {
    await _secureStorage.write(
      key: _credentialsKey,
      value: jsonEncode(creds),
    );
  }

  Future<Map<String, Map<String, String>>> loadCredentials() async {
    final json = await _secureStorage.read(key: _credentialsKey);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>).cast<String, String>(),
        ));
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _credentialsKey);
  }

  // ─── Serialization ───────────────────────────────────────────────────────────

  Map<String, dynamic> _postToMap(Post post) => {
        'id': post.id,
        'source': post.source.name,
        'thumbnailUrl': post.thumbnailUrl,
        'previewUrl': post.previewUrl,
        'fileUrl': post.fileUrl,
        'sampleUrl': post.sampleUrl,
        'width': post.width,
        'height': post.height,
        'fileType': post.fileType.name,
        'rating': post.rating.name,
        'score': post.score,
        'favoriteCount': post.favoriteCount,
        'tags': post.tags
            .map((t) => {'name': t.name, 'category': t.category})
            .toList(),
        'md5': post.md5,
        'fileSize': post.fileSize,
        'createdAt': post.createdAt?.toIso8601String(),
        'uploaderName': post.uploaderName,
        'isFavorited': true,
      };

  Post _postFromMap(Map<String, dynamic> map) {
    final sourceName = map['source'] as String;
    final source = BooruSource.values.firstWhere(
      (s) => s.name == sourceName,
      orElse: () => BooruSource.rule34xxx,
    );

    final tags = (map['tags'] as List? ?? []).map((t) {
      final tm = t as Map<String, dynamic>;
      return PostTag(
        name: tm['name'] as String,
        category: tm['category'] as String,
      );
    }).toList();

    return Post(
      id: map['id'] as String,
      source: source,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      previewUrl: map['previewUrl'] as String?,
      fileUrl: map['fileUrl'] as String?,
      sampleUrl: map['sampleUrl'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      fileType: FileType.values.firstWhere(
        (f) => f.name == map['fileType'],
        orElse: () => FileType.image,
      ),
      rating: ContentRating.values.firstWhere(
        (r) => r.name == map['rating'],
        orElse: () => ContentRating.explicit,
      ),
      score: map['score'] as int? ?? 0,
      favoriteCount: map['favoriteCount'] as int?,
      tags: tags,
      md5: map['md5'] as String?,
      fileSize: map['fileSize'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      uploaderName: map['uploaderName'] as String?,
      status: PostStatus.active,
      isFavorited: true,
    );
  }
}
