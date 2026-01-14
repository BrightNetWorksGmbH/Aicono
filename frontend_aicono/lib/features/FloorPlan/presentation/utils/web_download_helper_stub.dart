// Stub file for non-web platforms
import 'dart:typed_data';

void downloadFileWeb(Uint8List bytes, String fileName) {
  // No-op for non-web platformsmm,k
  throw UnsupportedError('Web download is only supported on web platform');
}
