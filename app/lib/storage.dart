import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// مجلد حفظ الملفات: Android/data/<package>/files/FlixGo على أندرويد.
Future<Directory> downloadsDir() async {
  final base = Platform.isAndroid
      ? (await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory())
      : await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(base.path, 'FlixGo'));
  await dir.create(recursive: true);
  return dir;
}
