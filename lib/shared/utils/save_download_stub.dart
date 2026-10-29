import 'dart:typed_data';

/// Hands [bytes] to the browser as a file download. Only a browser has one;
/// other platforms save through their own paths.
void saveDownload(String name, Uint8List bytes, String mimeType) =>
    throw UnsupportedError('Browser downloads are web-only');
