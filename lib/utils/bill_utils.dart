String formatBillCode(dynamic id, String? createdAt) {
  int iid;
  if (id is int) {
    iid = id;
  } else {
    iid = int.tryParse(id?.toString() ?? '') ?? 0;
  }

  DateTime dt;
  if (createdAt == null) {
    dt = DateTime.now();
  } else {
    try {
      final sqliteSpaceTs = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\$');
      final normalized = sqliteSpaceTs.hasMatch(createdAt)
          ? createdAt.replaceFirst(' ', 'T') + 'Z'
          : createdAt;
      dt = DateTime.parse(normalized).toLocal();
    } catch (_) {
      dt = DateTime.now();
    }
  }

  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  final idPart = iid.toString().padLeft(4, '0');
  return 'E${dd}${mm}${yyyy}${idPart}';
}
