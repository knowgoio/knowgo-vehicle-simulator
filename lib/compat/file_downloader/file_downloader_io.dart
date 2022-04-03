import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FileDownloader {
  String? _baseDir = null;

  FileDownloader();

  Future<void> init() async {
    _baseDir = (await getApplicationSupportDirectory()).path;
  }

  String? download(List<int> bytes, String filename) {
    if (this._baseDir == null) {
      return null;
    } else {
      final path = this._baseDir! + p.separator + filename;
      final File file = File(path);
      file.writeAsBytesSync(bytes);
      return path;
    }
  }
}
