// ─────────────────────────────────────────────────────────────
// lib/data/models/sync_result.dart
// ─────────────────────────────────────────────────────────────

class SyncResult {
  final int addedFromRemote;
  final int pushedToRemote;

  const SyncResult({
    required this.addedFromRemote,
    required this.pushedToRemote,
  });

  bool get hasChanges => addedFromRemote > 0 || pushedToRemote > 0;

  String get snackbarMessage {
    if (addedFromRemote > 0 && pushedToRemote > 0) {
      return 'Library synced · '
          '${_n(addedFromRemote, 'title')} from other devices, '
          '${_n(pushedToRemote, 'title')} saved';
    }
    if (addedFromRemote > 0) {
      return 'Library synced · '
          '${_n(addedFromRemote, 'title')} added from your other devices';
    }
    if (pushedToRemote > 0) {
      return 'Library synced · '
          '${_n(pushedToRemote, 'title')} saved to your account';
    }
    return 'Library synced';
  }

  static String _n(int count, String noun) =>
      '$count ${count == 1 ? noun : '${noun}s'}';
}
