import 'package:flutter_test/flutter_test.dart';
import 'package:moko/core/config/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('defaultBaseUrl is valid', () {
      expect(ApiConfig.defaultBaseUrl, contains('pipinipon.site'));
    });

    test('sanitizeUrl handles valid URLs', () {
      expect(ApiConfig.sanitizeUrl('https://api.pipinipon.site/'), 'https://api.pipinipon.site');
    });
  });
}
