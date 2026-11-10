/// Service placeholder (proxy disabled by user request, using original URLs directly)
class StreamProxyService {
  StreamProxyService._();
  static final StreamProxyService instance = StreamProxyService._();

  bool shouldProxy(String url) => false;

  Future<String> getProxyUrl(String targetUrl) async => targetUrl;
}
