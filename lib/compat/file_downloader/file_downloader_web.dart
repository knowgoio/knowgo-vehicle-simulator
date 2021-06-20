import 'dart:convert';
import 'dart:html';

class FileDownloader {
  FileDownloader();

  Future<void> init() async {}

  String? download(List<int> bytes, String filename) {
    final content = base64Encode(bytes);
    final anchor = AnchorElement(
        href: 'data:application/octet-stream;charset=utf-16le;base64,$content')
      ..setAttribute('download', filename);

    // Trigger download automatically
    anchor.click();

    return filename;
  }
}
