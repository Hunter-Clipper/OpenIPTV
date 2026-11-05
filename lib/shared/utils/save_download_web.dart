import 'dart:html' as html;
import 'dart:typed_data';

void saveDownload(String name, Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)
    ..download = name
    ..style.display = 'none';
  html.document.body!.append(link);
  link.click();
  link.remove();
  html.Url.revokeObjectUrl(url);
}
