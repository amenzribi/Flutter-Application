/// Single mushaf verse: surah-local number (1-based) and its Uthmani text.
///
/// `n` is the surah-local `numberInSurah` used throughout legacy (`S.lastAyah`,
/// `S.audioPos`), never the Quran-wide ayah index.
class Ayah {
  const Ayah({required this.n, required this.text});

  /// Surah-local ayah number, 1-based.
  final int n;

  /// Uthmani-script text. Basmala is already stripped for ayah 1.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ayah && other.n == n && other.text == text);

  @override
  int get hashCode => Object.hash(n, text);

  @override
  String toString() => 'Ayah(n: $n, text: $text)';
}
