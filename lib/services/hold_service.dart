// Simple in-memory singleton service for temporary holds.
// Holds are kept in RAM for the lifetime of the running app (survive navigation)
// but are not written to disk or DB.

class HoldService {
  HoldService._();
  static final HoldService instance = HoldService._();

  // Intentionally `dynamic` so callers can store their own HeldBill type.
  final List<dynamic> holds = [];

  void add(dynamic h) => holds.add(h);

  void removeWhere(bool Function(dynamic) test) => holds.removeWhere(test);

  void replaceAt(int index, dynamic h) {
    if (index >= 0 && index < holds.length) {
      holds[index] = h;
    }
  }

  void clear() => holds.clear();
}
