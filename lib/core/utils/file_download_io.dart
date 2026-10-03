import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> downloadBytes(String filename, List<int> bytes, String mime) async {
  final directory = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
