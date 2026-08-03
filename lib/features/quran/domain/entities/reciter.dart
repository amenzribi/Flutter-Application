/// A single EveryAyah reciter entry, matching legacy `RECITERS[]`.
class Reciter {
  const Reciter({
    required this.id,
    required this.arabicName,
    required this.folders,
  });

  /// Stable id, stored verbatim in `S.reciter`. Also the primary EveryAyah
  /// folder name.
  final String id;

  final String arabicName;

  /// EveryAyah folder candidates, in failover order. `folders.first` is
  /// normally equal to [id]; a second/third entry is a bitrate mirror to
  /// try when the primary folder 404s.
  final List<String> folders;
}
