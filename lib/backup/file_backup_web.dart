import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get fileBackupSupported => true;

/// iPhone / iPad: files are best saved through the share sheet ("Enregistrer dans Fichiers").
bool get isAppleMobile {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  return RegExp(r'iPhone|iPad|iPod').hasMatch(ua) || (ua.contains('Macintosh') && nav.maxTouchPoints > 1);
}

/// Asks the browser not to evict the app's storage when space runs low.
Future<void> requestPersistentStorage() async {
  try {
    final storage = web.window.navigator.storage;
    final already = (await storage.persisted().toDart).toDart;
    if (!already) await storage.persist().toDart;
  } catch (_) {
    // Not supported: nothing to do.
  }
}

/// Must be called straight from a button press (browsers require a user gesture).
Future<bool> saveBackupFile(String fileName, String json) async {
  final parts = <JSAny>[json.toJS].toJS;
  if (isAppleMobile) {
    try {
      final file = web.File(parts, fileName, web.FilePropertyBag(type: 'application/json'));
      final data = web.ShareData(files: <web.File>[file].toJS, title: fileName);
      if (web.window.navigator.canShare(data)) {
        await web.window.navigator.share(data).toDart;
        return true;
      }
    } catch (e) {
      if (e.toString().contains('Abort')) return false; // the user closed the share sheet
      // Any other error: fall back to a plain download below.
    }
  }
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return true;
}

/// Must be called straight from a button press (browsers require a user gesture).
Future<String?> pickBackupFile() {
  final done = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.json,application/json,text/plain';
  // Attached to the page (hidden): some browsers, Safari on iPhone included, ignore detached inputs.
  input.style
    ..position = 'fixed'
    ..left = '-1000px'
    ..opacity = '0';
  web.document.body?.appendChild(input);
  void finish(String? text) {
    input.remove();
    if (!done.isCompleted) done.complete(text);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (file == null) return finish(null);
      file.text().toDart.then((t) => finish(t.toDart), onError: (Object _) => finish(null));
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}
