/// Placeholder for platforms without `dart:io`, such as the web.
class FileLauncherDesktop {
  FileLauncherDesktop._();

  /// Does nothing; only Windows and Linux register a desktop implementation.
  static void registerWith() {}
}
