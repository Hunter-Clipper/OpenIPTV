import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'dart:io';

/// Shared image cache manager with higher concurrency for faster loading.
class ImageCacheManager extends CacheManager {
  static const key = 'openiptvImageCache';
  static ImageCacheManager? _instance;

  factory ImageCacheManager() {
    _instance ??= ImageCacheManager._();
    return _instance!;
  }

  ImageCacheManager._()
      : super(Config(
          key,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 1000,
          fileService: HttpFileService(
            httpClient: _createHttpClient(),
          ),
        ));

  static http.Client _createHttpClient() {
    final ioClient = HttpClient();
    ioClient.maxConnectionsPerHost = 24;
    return io_client.IOClient(ioClient);
  }
}
