// Web download helper using dart:html
// This file is only imported on web platform

import 'dart:html' as html;
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName);
  anchor.click();
  html.Url.revokeObjectUrl(url);
}

