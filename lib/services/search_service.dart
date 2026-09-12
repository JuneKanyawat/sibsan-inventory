import 'dart:math';

/// Service for fuzzy text search and autocomplete suggestions.
/// Uses Levenshtein distance for approximate string matching —
/// particularly useful for Thai transliteration variations
/// (e.g. คลัช vs คลัทช์, เบรค vs เบรก).
class SearchService {
  /// Calculates the Levenshtein (edit) distance between two strings.
  /// This is the minimum number of single-character edits
  /// (insertions, deletions, substitutions) to change one string to the other.
  static int levenshteinDistance(String s, String t) {
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    if (s == t) return 0;

    final sLen = s.length;
    final tLen = t.length;

    // Use two rows instead of full matrix for space efficiency
    var prevRow = List<int>.generate(tLen + 1, (j) => j);
    var currRow = List<int>.filled(tLen + 1, 0);

    for (int i = 1; i <= sLen; i++) {
      currRow[0] = i;
      for (int j = 1; j <= tLen; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        currRow[j] = [
          prevRow[j] + 1, // deletion
          currRow[j - 1] + 1, // insertion
          prevRow[j - 1] + cost, // substitution
        ].reduce(min);
      }
      // Swap rows
      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[tLen];
  }

  /// Returns a normalized similarity score between 0.0 and 1.0.
  /// 1.0 means identical, 0.0 means completely different.
  static double similarity(String s, String t) {
    if (s.isEmpty && t.isEmpty) return 1.0;
    final maxLen = max(s.length, t.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (levenshteinDistance(s, t) / maxLen);
  }

  /// Checks if [query] fuzzy-matches [text].
  /// First tries exact substring match (fast path),
  /// then falls back to word-level fuzzy matching.
  static bool fuzzyMatch(String query, String text, {double threshold = 0.55}) {
    if (query.isEmpty) return true;

    query = query.toLowerCase();
    text = text.toLowerCase();

    // Fast path: exact substring match
    if (text.contains(query)) return true;

    // Whole-string similarity
    if (similarity(query, text) >= threshold) return true;

    // Word-level fuzzy matching
    final textWords = text.split(RegExp(r'\s+'));
    for (final word in textWords) {
      if (word.isEmpty) continue;

      // Exact substring within word
      if (word.contains(query)) return true;

      // Word similarity
      if (similarity(query, word) >= threshold) return true;

      // Sliding window: check if query is a fuzzy substring of word
      if (word.length >= query.length) {
        for (int i = 0; i <= word.length - query.length; i++) {
          final sub = word.substring(i, i + query.length);
          if (similarity(query, sub) >= threshold + 0.1) return true;
        }
      }
    }

    return false;
  }

  /// Returns autocomplete suggestions from [candidates] that match [query].
  /// Results are sorted by relevance (prefix > contains > fuzzy).
  /// Returns at most [maxResults] suggestions.
  static List<String> getSuggestions(
    String query,
    List<String> candidates, {
    int maxResults = 5,
  }) {
    if (query.isEmpty || query.length < 2) return [];
    query = query.toLowerCase();

    final scored = <_ScoredItem>[];
    final seen = <String>{};

    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      final lower = candidate.toLowerCase();
      if (seen.contains(lower)) continue;
      // Don't suggest the exact same text they already typed
      if (lower == query) continue;
      seen.add(lower);

      double score = 0;

      // Exact prefix match (highest priority)
      if (lower.startsWith(query)) {
        score = 3.0;
      }
      // Word starts with query
      else if (lower.split(RegExp(r'\s+')).any((w) => w.startsWith(query))) {
        score = 2.5;
      }
      // Contains substring
      else if (lower.contains(query)) {
        score = 2.0;
      }
      // Fuzzy match
      else {
        // Check whole string similarity
        double bestScore = similarity(query, lower);

        // Check word-level similarity
        for (final word in lower.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          final wordSim = similarity(query, word);
          if (wordSim > bestScore) bestScore = wordSim;
        }

        if (bestScore >= 0.45) {
          score = bestScore;
        }
      }

      if (score > 0) {
        scored.add(_ScoredItem(candidate, score));
      }
    }

    // Sort by score descending, then by name length ascending (prefer shorter names)
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.text.length.compareTo(b.text.length);
    });

    return scored.take(maxResults).map((e) => e.text).toList();
  }
}

class _ScoredItem {
  final String text;
  final double score;
  const _ScoredItem(this.text, this.score);
}
