/// The single reading bookmark legacy exposes ("وصلت هنا" / "آخر موضع").
///
/// There is deliberately **no** list type here — Option A (legacy-faithful)
/// keeps exactly one bookmark, backed by `S.lastAyah`.
class Bookmark {
  const Bookmark(this.ayah);

  /// Bookmarked surah-local ayah number, or `null` when unset.
  final int? ayah;

  bool get isSet => ayah != null;

  bool isAt(int n) => ayah == n;

  /// Legacy toggle semantics: tapping the bookmark control on the ayah
  /// already bookmarked clears it; tapping it on any other ayah moves the
  /// bookmark there.
  Bookmark toggledAt(int n) => isAt(n) ? const Bookmark(null) : Bookmark(n);
}
