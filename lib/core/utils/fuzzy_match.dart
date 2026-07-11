/// Typo-tolerant matching for autocomplete (Saad, 2026-07-11: "some people
/// are just bad at typing"). Bounded Damerau-Levenshtein so "mlik" finds
/// Milk and "tomatos" finds Tomatoes. The budget scales with query length
/// and queries under 4 characters never fuzz — too noisy.
library;

import 'dart:math' as math;

/// Damerau-Levenshtein distance between [a] and [b], giving up (returns
/// `max + 1`) as soon as the distance must exceed [max].
int boundedDamerau(String a, String b, int max) {
  if ((a.length - b.length).abs() > max) return max + 1;
  if (a == b) return 0;

  final m = a.length;
  final n = b.length;
  var prevPrev = List<int>.filled(n + 1, 0);
  var prev = List<int>.generate(n + 1, (j) => j);
  var current = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= m; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = math.min(
        math.min(prev[j] + 1, current[j - 1] + 1),
        prev[j - 1] + cost,
      );
      if (i > 1 &&
          j > 1 &&
          a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
          a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
        current[j] = math.min(current[j], prevPrev[j - 2] + 1);
      }
      rowMin = math.min(rowMin, current[j]);
    }
    if (rowMin > max) return max + 1;
    final recycled = prevPrev;
    prevPrev = prev;
    prev = current;
    current = recycled;
  }
  return prev[n];
}

/// Edit budget for a query: nothing under 4 chars, then roughly one typo
/// per four characters.
int _budget(int queryLength) {
  if (queryLength < 4) return 0;
  if (queryLength <= 5) return 1;
  if (queryLength <= 8) return 2;
  return 3;
}

/// Whether [query] plausibly means [candidate] despite typos. Checks the
/// whole candidate, its same-length prefix (mid-word typing), and each
/// word of multi-word candidates.
bool fuzzyMatches(String query, String candidate) {
  final max = _budget(query.length);
  if (max == 0) return false;

  if (boundedDamerau(query, candidate, max) <= max) return true;

  // Typing the front of a longer name: compare against its prefix.
  if (candidate.length > query.length) {
    final prefix = candidate.substring(0, query.length);
    if (boundedDamerau(query, prefix, max) <= max) return true;
  }

  if (candidate.contains(' ')) {
    for (final word in candidate.split(' ')) {
      if (word.length >= 3 && boundedDamerau(query, word, max) <= max) {
        return true;
      }
    }
  }
  return false;
}

/// Distance used to rank fuzzy hits (lower = closer).
int fuzzyDistance(String query, String candidate) {
  final max = _budget(query.length);
  var best = boundedDamerau(query, candidate, max);
  if (candidate.length > query.length) {
    best = math.min(
      best,
      boundedDamerau(query, candidate.substring(0, query.length), max),
    );
  }
  if (candidate.contains(' ')) {
    for (final word in candidate.split(' ')) {
      if (word.length >= 3) {
        best = math.min(best, boundedDamerau(query, word, max));
      }
    }
  }
  return best;
}
