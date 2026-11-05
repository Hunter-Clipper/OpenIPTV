import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Shared image cache manager. Every poster, logo and backdrop in the app
/// goes through it, so one cache (not the library's default 200-image one)
/// holds what you browse.
class ImageCacheManager extends CacheManager {
  static const key = 'openiptvImageCache';

  /// How many images the cache keeps, and how many download at once.
  static const maxCacheObjects = 3000;
  static const concurrentDownloads = 20;
  static ImageCacheManager? _instance;

  factory ImageCacheManager() {
    _instance ??= ImageCacheManager._();
    return _instance!;
  }

  ImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          // A big catalogue has tens of thousands of logos and posters.
          maxNrOfCacheObjects: maxCacheObjects,
          fileService: createFileService(),
        ));

  /// The library downloads at most 10 files at once by default (that, not the
  /// connection limit below, was the real cap); on a slow or high-latency
  /// network more in flight at a time fills the screen faster.
  @visibleForTesting
  static HttpFileService createFileService() =>
      HttpFileService(httpClient: _createHttpClient())
        ..concurrentFetches = concurrentDownloads;

  static http.Client _createHttpClient() {
    // dart:io's HttpClient doesn't exist in a browser; use its own client.
    if (kIsWeb) return http.Client();
    final ioClient = HttpClient();
    ioClient.maxConnectionsPerHost = 24;
    return io_client.IOClient(ioClient);
  }
}
