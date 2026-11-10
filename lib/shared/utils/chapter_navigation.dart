/// Generic helpers to resolve previous/next chapter navigation that work no
/// matter how a source orders its chapter list (ascending or descending).
///
/// Historically the readers assumed "index + 1 = next chapter", but most comic
/// sources list chapters newest-first, which made the Next/Previous buttons
/// appear swapped. [ChapterNavigator] fixes this by comparing chapter numbers.
class ChapterNavigator<T> {
  ChapterNavigator({
    required this.items,
    required this.currentIndex,
    required this.numberOf,
  });

  /// The chapter list as received from the source (any order).
  final List<T> items;

  /// Index of the chapter currently being read, or -1 when unknown.
  final int currentIndex;

  /// Extracts a comparable chapter number from an item (e.g. "Chapter 12.5"
  /// -> 12.5). Return null when no number can be found.
  final double? Function(T item) numberOf;

  bool get _hasValidIndex => currentIndex >= 0 && currentIndex < items.length;

  double? get _currentNumber {
    if (!_hasValidIndex) return null;
    return numberOf(items[currentIndex]);
  }

  /// The previous (older) chapter, or null when there is none.
  T? get previous {
    if (!_hasValidIndex) return null;

    final currentNum = _currentNumber;
    // Without a chapter number we can only fall back to list position.
    if (currentNum == null) {
      final target = currentIndex + 1; // sources are usually descending
      if (target >= 0 && target < items.length) return items[target];
      final alt = currentIndex - 1;
      return (alt >= 0 && alt < items.length) ? items[alt] : null;
    }

    T? best;
    double? bestNum;
    for (var i = 0; i < items.length; i++) {
      final num = numberOf(items[i]);
      if (num == null || num >= currentNum) continue;
      if (bestNum == null || num > bestNum) {
        bestNum = num;
        best = items[i];
      }
    }
    return best;
  }

  /// The next (newer) chapter, or null when there is none.
  T? get next {
    if (!_hasValidIndex) return null;

    final currentNum = _currentNumber;
    if (currentNum == null) {
      final target = currentIndex - 1; // sources are usually descending
      if (target >= 0 && target < items.length) return items[target];
      final alt = currentIndex + 1;
      return (alt >= 0 && alt < items.length) ? items[alt] : null;
    }

    T? best;
    double? bestNum;
    for (var i = 0; i < items.length; i++) {
      final num = numberOf(items[i]);
      if (num == null || num <= currentNum) continue;
      if (bestNum == null || num < bestNum) {
        bestNum = num;
        best = items[i];
      }
    }
    return best;
  }
}
