import 'package:flutter/material.dart';

/// Widget animasi angka Count Up yang bertambah secara halus dari 0 ke angka target saat data termuat.
class CountUpText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  const CountUpText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.overflow,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    // Ekstrak angka pertama dan bagian desimal jika ada
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (match == null) {
      // Tidak ada angka (contoh: "Ongoing", "Completed", "Manga")
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    final numStr = match.group(1)!;
    final targetValue = double.tryParse(numStr);
    if (targetValue == null) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
      );
    }

    final prefix = trimmed.substring(0, match.start);
    final suffix = trimmed.substring(match.end);
    final isDecimal = numStr.contains('.');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final formattedNumber = isDecimal
            ? value.toStringAsFixed(1)
            : value.round().toString();
        return Text(
          '$prefix$formattedNumber$suffix',
          style: style,
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}
