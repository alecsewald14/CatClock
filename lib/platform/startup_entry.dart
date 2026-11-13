/// Whether the app starts by itself when the person signs in to the computer.
abstract interface class StartupEntry {
  Future<bool> isEnabled();

  /// Turns starting at sign-in on or off. Throws if it cannot be done.
  Future<void> setEnabled(bool enabled);
}
