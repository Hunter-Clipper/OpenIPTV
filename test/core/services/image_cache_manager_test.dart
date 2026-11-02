import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/image_cache_manager.dart';

void main() {
  test('the shared image cache is sized for a big catalogue', () {
    // The library defaults (200 images, 10 downloads at a time) are too
    // small for tens of thousands of logos and posters.
    expect(ImageCacheManager.maxCacheObjects, 3000);
    expect(ImageCacheManager.createFileService().concurrentFetches, 20);
  });
}
