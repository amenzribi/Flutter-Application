/// Read-only view over the two legacy position fields
/// (`S.lastAyah` / `S.audioPos`) with the small helpers legacy inlines at
/// call sites (`S.audioPos||S.lastAyah`, `Math.min(n,286)/286`).
///
/// This never invents a position: both fields default to `null` and stay
/// `null` until the user actually bookmarks or plays something.
class QuranReadingPosition {
  const QuranReadingPosition({this.lastAyah, this.audioPos});

  /// Total ayahs in Al-Baqarah, used to clamp/percent a position.
  static const int totalAyahs = 286;

  /// Bookmarked ayah ("وصلت هنا" / "آخر موضع"), or `null`.
  final int? lastAyah;

  /// Last/currently playing ayah, or `null` (cleared on stop).
  final int? audioPos;

  /// Legacy `S.audioPos||S.lastAyah` — prefers the live playback position,
  /// falling back to the manual bookmark.
  int? get effectiveAyah => audioPos ?? lastAyah;

  bool get hasPosition => effectiveAyah != null;

  /// `Math.round(Math.min(n,286)/286*100)` — `null` when there's no
  /// position yet, never a fake `0%`.
  double? get percent {
    final n = effectiveAyah;
    if (n == null || n < 1) return null;
    final clamped = n.clamp(0, totalAyahs);
    return clamped / totalAyahs * 100;
  }
}
