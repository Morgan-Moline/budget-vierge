/// Backup files: real files on the web, nothing on other platforms (clipboard is used there).
library;

export 'file_backup_stub.dart' if (dart.library.js_interop) 'file_backup_web.dart';
