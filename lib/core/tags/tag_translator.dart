import '../../domain/entities/post.dart';

/// Canonicalizes a raw user-typed tag into the app's internal canonical
/// form: lowercase, whitespace/hyphens collapsed to underscores, trimmed.
/// This is the single normalization step every tag passes through before
/// any site-specific translation happens.
String canonicalizeTag(String raw) {
  var t = raw.trim().toLowerCase();
  t = t.replaceAll(RegExp(r'[\s-]+'), '_');
  t = t.replaceAll(RegExp(r'_+'), '_');
  return t;
}

/// Centralized cross-site tag translation.
///
/// Architecture: user input -> canonical tags -> per-source translator ->
/// site-specific query string. Every booru datasource should build its
/// tag string by calling [TagTranslator.translateForSource] instead of
/// joining `query.tags` directly, so tag handling lives in one place
/// rather than being duplicated (and drifting) across every datasource.
class TagTranslator {
  TagTranslator._();

  /// Aliases: canonical tag -> the equivalent tag on a given source, when
  /// that source spells/names the concept differently. Only exceptions
  /// need an entry here - anything absent falls through unchanged (after
  /// canonicalization), since most tags are shared verbatim across these
  /// sites. This is intentionally a small seed table: extend it as
  /// mismatches are discovered, rather than scattering one-off fixes
  /// through the UI or individual datasources.
  static final Map<BooruSource, Map<String, String>> _aliases = {
    BooruSource.e621: {
      // e621 prefers "anthro" as the umbrella term some other sites tag
      // as "furry" for the species-general case.
      'furry': 'anthro',
      // The broader Rule34.xxx tag is indexed as big_penis on e621.
      'huge_penis': 'big_penis',
      'porn': 'explicit',
    },
    BooruSource.rule34xxx: {
      'anthro': 'furry',
    },
    BooruSource.gelbooru: {},
    BooruSource.paheal: {},
  };

  /// Tags that don't make sense / aren't supported on a given source and
  /// should be dropped from that source's query rather than sent as a
  /// literal (and likely no-op or error-triggering) tag.
  static final Map<BooruSource, Set<String>> _unsupported = {
    BooruSource.paheal: {'score'}, // paheal's tag search has no score: operator
  };

  /// Canonicalizes and translates [rawTags] for [source], returning the
  /// individual translated tags (unsupported ones dropped). Callers that
  /// need to append site-specific meta-operators (rating:, score:, etc.)
  /// after translation should use this and join the result themselves;
  /// [translateForSource] is the convenience wrapper for the common case
  /// of just wanting the final joined tag string.
  static List<String> translate(List<String> rawTags, BooruSource source) {
    final aliases = _aliases[source] ?? const {};
    final unsupported = _unsupported[source] ?? const {};

    return rawTags
        .map(canonicalizeTag)
        .where((t) => t.isNotEmpty)
        .where((t) => !unsupported.contains(_operatorName(t)))
        .map((t) => aliases[t] ?? t)
        .toList();
  }

  /// Canonicalizes, translates, then joins [rawTags] into the exact
  /// query-string syntax [source]'s search endpoint expects.
  static String translateForSource(List<String> rawTags, BooruSource source) {
    return translate(rawTags, source).join(_separator(source));
  }

  /// The separator each source's dapi/API expects between tags.
  static String separator(BooruSource source) => _separator(source);

  static String _separator(BooruSource source) {
    switch (source) {
      case BooruSource.rule34xxx:
      case BooruSource.gelbooru:
      case BooruSource.xbooru:
        // Dio encodes query parameter values itself. Passing a literal plus
        // here becomes `%2B` and these APIs treat it as part of the tag.
        // Spaces are correctly encoded and decoded as tag separators.
        return ' ';
      case BooruSource.e621:
      case BooruSource.paheal:
      case BooruSource.danbooru:
        return ' ';
    }
  }

  /// For a meta-tag like `score:>50`, returns the operator name
  /// (`score`) so it can be matched against a source's unsupported set
  /// regardless of the comparison value.
  static String _operatorName(String tag) {
    final colon = tag.indexOf(':');
    return colon == -1 ? tag : tag.substring(0, colon);
  }
}
