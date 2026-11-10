import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:moko/core/utils/apng_sanitizer.dart';

void main() {
  group('ApngSanitizer', () {
    test('isPng detects valid and invalid signatures', () {
      final validPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00]);
      final invalid = Uint8List.fromList([0x52, 0x49, 0x46, 0x46]); // RIFF (WebP)

      expect(ApngSanitizer.isPng(validPng), isTrue);
      expect(ApngSanitizer.isPng(invalid), isFalse);
      expect(ApngSanitizer.isPng(Uint8List(0)), isFalse);
    });

    test('non-png bytes pass through unchanged', () {
      final nonPng = Uint8List.fromList([1, 2, 3, 4, 5]);
      final result = ApngSanitizer.sanitize(nonPng);
      expect(result, equals(nonPng));
    });

    test('patches fcTL chunk with dispose_op != 1 to dispose_op = 1 and recalculates CRC', () {
      // Create minimal fake PNG with fcTL chunk (length 26)
      final pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      final chunkLen = [0x00, 0x00, 0x00, 0x1A]; // 26 bytes
      final chunkType = [0x66, 0x63, 0x54, 0x4C]; // fcTL
      final chunkData = List<int>.filled(26, 0);
      chunkData[24] = 0; // dispose_op = APNG_DISPOSE_OP_NONE (0)
      final dummyCrc = [0x00, 0x00, 0x00, 0x00];

      final rawBytes = Uint8List.fromList([
        ...pngHeader,
        ...chunkLen,
        ...chunkType,
        ...chunkData,
        ...dummyCrc,
      ]);

      final sanitized = ApngSanitizer.sanitize(rawBytes);

      // dispose_op should now be 1
      expect(sanitized[8 + 4 + 4 + 24], equals(1));

      // CRC at end should be recalculated (non-zero)
      const crcOffset = 8 + 4 + 4 + 26;
      final newCrc = ByteData.sublistView(sanitized, crcOffset, crcOffset + 4).getUint32(0);
      expect(newCrc, isNot(0));
    });

    test('preserves delta-frame APNG (sub-rectangles) untouched to prevent flickering', () {
      final pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

      // IHDR chunk (288x288)
      final ihdrLen = [0x00, 0x00, 0x00, 0x0D]; // 13 bytes
      final ihdrType = [0x49, 0x48, 0x44, 0x52]; // IHDR
      final ihdrData = [
        0x00, 0x00, 0x01, 0x20, // width: 288
        0x00, 0x00, 0x01, 0x20, // height: 288
        0x08, 0x06, 0x00, 0x00, 0x00,
      ];
      final ihdrCrc = [0x00, 0x00, 0x00, 0x00];

      // Frame 0 fcTL: full canvas 288x288 at (0,0), dispose_op = 0
      final fctl1Len = [0x00, 0x00, 0x00, 0x1A];
      final fctl1Type = [0x66, 0x63, 0x54, 0x4C];
      final fctl1Data = List<int>.filled(26, 0);
      fctl1Data[6] = 0x01; fctl1Data[7] = 0x20; // w = 288
      fctl1Data[10] = 0x01; fctl1Data[11] = 0x20; // h = 288
      fctl1Data[24] = 0; // dispose_op = 0

      // Frame 1 fcTL: sub-rectangle 60x60 at (10, 10), dispose_op = 0
      final fctl2Len = [0x00, 0x00, 0x00, 0x1A];
      final fctl2Type = [0x66, 0x63, 0x54, 0x4C];
      final fctl2Data = List<int>.filled(26, 0);
      fctl2Data[7] = 60; // w = 60
      fctl2Data[11] = 60; // h = 60
      fctl2Data[15] = 10; // x = 10
      fctl2Data[19] = 10; // y = 10
      fctl2Data[24] = 0; // dispose_op = 0

      final dummyCrc = [0x00, 0x00, 0x00, 0x00];

      final rawBytes = Uint8List.fromList([
        ...pngHeader,
        ...ihdrLen, ...ihdrType, ...ihdrData, ...ihdrCrc,
        ...fctl1Len, ...fctl1Type, ...fctl1Data, ...dummyCrc,
        ...fctl2Len, ...fctl2Type, ...fctl2Data, ...dummyCrc,
      ]);

      final sanitized = ApngSanitizer.sanitize(rawBytes);

      // Delta APNG must be returned untouched (same instance, dispose_op intact)
      expect(identical(sanitized, rawBytes), isTrue);
      // dispose_op on Frame 0 should still be 0 (not wiped to background)
      const fctl1DisposeOffset = 8 + 12 + 13 + 4 + 4 + 24;
      expect(sanitized[fctl1DisposeOffset], equals(0));
    });

    test('patches full-canvas APNG with IHDR when dispose_op == 0', () {
      final pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

      // IHDR chunk (288x288)
      final ihdrLen = [0x00, 0x00, 0x00, 0x0D]; // 13 bytes
      final ihdrType = [0x49, 0x48, 0x44, 0x52]; // IHDR
      final ihdrData = [
        0x00, 0x00, 0x01, 0x20, // width: 288
        0x00, 0x00, 0x01, 0x20, // height: 288
        0x08, 0x06, 0x00, 0x00, 0x00,
      ];
      final ihdrCrc = [0x00, 0x00, 0x00, 0x00];

      // Frame 0 fcTL: full canvas 288x288 at (0,0), dispose_op = 0
      final fctl1Len = [0x00, 0x00, 0x00, 0x1A];
      final fctl1Type = [0x66, 0x63, 0x54, 0x4C];
      final fctl1Data = List<int>.filled(26, 0);
      fctl1Data[6] = 0x01; fctl1Data[7] = 0x20; // w = 288
      fctl1Data[10] = 0x01; fctl1Data[11] = 0x20; // h = 288
      fctl1Data[24] = 0; // dispose_op = 0

      final dummyCrc = [0x00, 0x00, 0x00, 0x00];

      final rawBytes = Uint8List.fromList([
        ...pngHeader,
        ...ihdrLen, ...ihdrType, ...ihdrData, ...ihdrCrc,
        ...fctl1Len, ...fctl1Type, ...fctl1Data, ...dummyCrc,
      ]);

      final sanitized = ApngSanitizer.sanitize(rawBytes);

      // Full canvas APNG should be patched to dispose_op = 1
      const fctl1DisposeOffset = 8 + 12 + 13 + 4 + 4 + 24;
      expect(sanitized[fctl1DisposeOffset], equals(1));
    });
  });
}
