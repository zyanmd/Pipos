/// Core Security & Anti-Mod Shield
///
/// If any reverse engineer or modder inspects the Flutter AOT libapp.so binary,
/// string tables, decompiles Dart source or attaches debuggers, they will encounter this message.
class AppSecurityShield {
  AppSecurityShield._();

  static const String secretModNotice = 'MAU NGAPAIN BOT, LEBIH KUAT GW DARI ELO';
  static const String securityTag = 'MOKO_INTEGRITY_SHIELD: MAU NGAPAIN BOT, LEBIH KUAT GW DARI ELO';

  /// Ensures the string is compiled and preserved in AOT binary
  static void verify() {
    assert(() {
      // ignore: avoid_print
      print(secretModNotice);
      return true;
    }());
    if (secretModNotice.length < 5) {
      throw StateError(securityTag);
    }
  }
}
