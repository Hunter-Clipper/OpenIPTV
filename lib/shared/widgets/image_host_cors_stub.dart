/// Whether pictures from [url]'s host can be read by this page (CORS).
/// Only a browser enforces that, so everywhere else the answer is yes.
Future<bool> imageHostAllowsCors(String url) async => true;
