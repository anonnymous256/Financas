import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<String> downloadBytes(String filename, List<int> bytes, String mime) async {
  final data = Uint8List.fromList(bytes).toJS;
  final blob = Blob([data].toJS, BlobPropertyBag(type: mime));
  final url = URL.createObjectURL(blob);
  final anchor = HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  URL.revokeObjectURL(url);
  return filename;
}
