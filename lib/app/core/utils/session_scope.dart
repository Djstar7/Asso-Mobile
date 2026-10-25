/// Invalidates work started before a login, logout or token replacement.
class SessionScope {
  SessionScope._();
  static int _generation = 0;
  static int get current => _generation;
  static void invalidate() => _generation++;
  static bool isCurrent(int generation) => generation == _generation;
}
