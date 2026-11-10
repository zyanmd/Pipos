import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility to inspect and sanitize APNG (Animated PNG) byte streams.
///
/// Problem:
/// Many APNG files (such as those exported from older tools, Discord rips, or Ezgif with
/// default settings) have `dispose_op = 0` (APNG_DISPOSE_OP_NONE) in their `fcTL` chunks.
/// In Flutter / Skia / Impeller, rendering transparent APNG frames with `dispose_op = 0`
/// causes previous frames to stack/accumulate without being cleared to background,
/// resulting in ghosting trails ("jejak animasi" menumpuk).
///
/// Solution:
/// This sanitizer inspects the APNG chunk stream in-memory. If any `fcTL` chunk has
/// `dispose_op == 0`, it updates it to `1` (APNG_DISPOSE_OP_BACKGROUND) and updates
/// the 32-bit CRC. Skia / Impeller will then cleanly clear the background between frames.
class ApngSanitizer {
  ApngSanitizer._();

  // CRC-32 table generator conforming to ISO 3309 / PNG specification
  static final List<int> _crcTable = () {
    final table = List<int>.filled(256, 0);
    for (int n = 0; n < 256; n++) {
      int c = n;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xedb88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[n] = c;
    }
    return table;
  }();

  static int _crc32(Uint8List data, int start, int end) {
    int c = 0xffffffff;
    for (int i = start; i < end; i++) {
      c = _crcTable[(c ^ data[i]) & 0xff] ^ (c >>> 8);
    }
    return c ^ 0xffffffff;
  }

  /// Checks whether bytes start with PNG 8-byte signature:
  /// 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
  static bool isPng(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// Checks whether bytes start with WebP signature: RIFF....WEBP
  static bool isWebp(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50; // P
  }

  /// Sanitizes APNG in memory.
  ///
  /// If the file is not PNG or is a delta-frame APNG (containing sub-rectangle frames
  /// that rely on preserving canvas contents across frames), the original bytes
  /// are returned directly unmodified to prevent flickering / blinking ("kerlap-kerlip").
  ///
  /// Only full-canvas animations where every frame covers the entire canvas (width == canvasWidth,
  /// height == canvasHeight, xOffset == 0, yOffset == 0) and dispose_op == 0 are patched
  /// to dispose_op = 1 (APNG_DISPOSE_OP_BACKGROUND) to eliminate ghosting accumulation.
  static Uint8List sanitize(Uint8List bytes) {
    if (!isPng(bytes)) return bytes;

    int offset = 8; // skip 8-byte PNG header
    final length = bytes.length;

    int canvasWidth = 0;
    int canvasHeight = 0;
    bool hasSubRectangles = false;
    final List<int> candFctlChunkOffsets = [];

    while (offset + 12 <= length) {
      final chunkLen = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0);
      if (offset + 12 + chunkLen > length) break;

      final type0 = bytes[offset + 4];
      final type1 = bytes[offset + 5];
      final type2 = bytes[offset + 6];
      final type3 = bytes[offset + 7];

      // Match 'IHDR' chunk: 0x49, 0x48, 0x44, 0x52
      if (type0 == 0x49 && type1 == 0x48 && type2 == 0x44 && type3 == 0x52 && chunkLen >= 8) {
        canvasWidth = ByteData.sublistView(bytes, offset + 8, offset + 12).getUint32(0);
        canvasHeight = ByteData.sublistView(bytes, offset + 12, offset + 16).getUint32(0);
      }

      // Match 'fcTL' chunk: 0x66, 0x63, 0x54, 0x4C
      if (type0 == 0x66 && type1 == 0x63 && type2 == 0x54 && type3 == 0x4C && chunkLen >= 26) {
        final dataOffset = offset + 8;
        final frameW = ByteData.sublistView(bytes, dataOffset + 4, dataOffset + 8).getUint32(0);
        final frameH = ByteData.sublistView(bytes, dataOffset + 8, dataOffset + 12).getUint32(0);
        final xOffset = ByteData.sublistView(bytes, dataOffset + 12, dataOffset + 16).getUint32(0);
        final yOffset = ByteData.sublistView(bytes, dataOffset + 16, dataOffset + 20).getUint32(0);
        final currentDisposeOp = bytes[dataOffset + 24];

        // If canvas size is known and this frame is a sub-rectangle (delta frame):
        // Delta frames MUST NOT have dispose_op altered! Any modification would wipe out
        // the base frame and cause the animation to violently flash / blink ("kerlap-kerlip").
        if (canvasWidth > 0 && canvasHeight > 0) {
          if (frameW < canvasWidth || frameH < canvasHeight || xOffset > 0 || yOffset > 0) {
            hasSubRectangles = true;
            return bytes; // Return unmodified immediately
          }
        }

        // In full-canvas animations, if dispose_op == 0, Skia/Impeller will stack transparent
        // frames over each other causing ghosting accumulation ("jejak animasi").
        // We record this offset to patch dispose_op = 1 (APNG_DISPOSE_OP_BACKGROUND).
        if (currentDisposeOp == 0) {
          candFctlChunkOffsets.add(offset);
        }
      }

      // If 'IEND' chunk reached, stop parsing
      if (type0 == 0x49 && type1 == 0x45 && type2 == 0x4E && type3 == 0x44) {
        break;
      }

      offset += 12 + chunkLen;
    }

    if (hasSubRectangles || candFctlChunkOffsets.isEmpty) {
      return bytes;
    }

    // Full-canvas APNG with dispose_op == 0: patch to dispose_op = 1
    final mutableBytes = Uint8List.fromList(bytes);
    for (final chunkOffset in candFctlChunkOffsets) {
      final chunkLen = ByteData.sublistView(mutableBytes, chunkOffset, chunkOffset + 4).getUint32(0);
      final dataOffset = chunkOffset + 8;
      mutableBytes[dataOffset + 24] = 1; // APNG_DISPOSE_OP_BACKGROUND

      // Recalculate CRC (over Chunk Type + Chunk Data = 4 + chunkLen bytes)
      final newCrc = _crc32(mutableBytes, chunkOffset + 4, chunkOffset + 8 + chunkLen);
      ByteData.sublistView(
        mutableBytes,
        chunkOffset + 8 + chunkLen,
        chunkOffset + 12 + chunkLen,
      ).setUint32(0, newCrc);
    }

    return mutableBytes;
  }

  /// Synchronously sanitizes a local APNG file if needed.
  static Future<File> sanitizeFile(File file) async {
    try {
      if (!await file.exists()) return file;
      final bytes = await file.readAsBytes();
      final sanitized = sanitize(bytes);
      if (identical(sanitized, bytes)) return file;
      await file.writeAsBytes(sanitized, flush: true);
      return file;
    } catch (e) {
      debugPrint('ApngSanitizer sanitizeFile error: $e');
      return file;
    }
  }
}
