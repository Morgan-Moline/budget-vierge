/// Non-web platforms: no file backup (the clipboard is offered instead).
bool get fileBackupSupported => false;

/// True on iPhone / iPad (web only).
bool get isAppleMobile => false;

Future<void> requestPersistentStorage() async {}

/// Saves [json] as a file. Returns false if nothing was saved (cancelled or unsupported).
Future<bool> saveBackupFile(String fileName, String json) async => false;

/// Lets the user pick a backup file. Returns its text, or null if cancelled.
Future<String?> pickBackupFile() async => null;
