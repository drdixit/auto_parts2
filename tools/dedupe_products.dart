// One-time DB cleanup script to merge exact duplicate products.
// Usage: dart run tools/dedupe_products.dart <path-to-auto_parts.db>
// Note: This script is conservative and only merges products that have the same
// manufacturer_id and identical part_number (case-insensitive, trimmed).
// It will: reassign product_images, product_inventory, product_compatibility
// rows to the chosen canonical product id, update product_id occurrences inside
// `customer_bills.items` JSON arrays, and then delete the duplicate product rows.
// Review the printed log before and after running. Backup your DB first.

import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tools/dedupe_products.dart <path-to-auto_parts.db>');
    exit(1);
  }

  final dbPath = args[0];
  if (!await File(dbPath).exists()) {
    print('Database file not found at: $dbPath');
    exit(1);
  }

  // Prepare FFI factory for desktop sqlite access
  sqfliteFfiInit();
  final dbFactory = databaseFactoryFfi;

  final db = await dbFactory.openDatabase(dbPath);
  try {
    print('Opened DB: $dbPath');

    // Run in a transaction for safety
    await db.transaction((txn) async {
      // Find groups of products with same manufacturer_id and identical part_number (case-insensitive)
      final groups = await txn.rawQuery('''
        SELECT manufacturer_id, TRIM(LOWER(part_number)) as part_clean, COUNT(1) as cnt
        FROM products
        WHERE part_number IS NOT NULL AND TRIM(part_number) != ''
        GROUP BY manufacturer_id, part_clean
        HAVING cnt > 1
      ''');

      if (groups.isEmpty) {
        print(
          'No exact duplicate products (manufacturer + part_number) found.',
        );
        return;
      }

      for (final g in groups) {
        final manufacturerId = g['manufacturer_id'];
        final partClean = g['part_clean'] as String? ?? '';
        final productRows = await txn.rawQuery(
          '''SELECT id, name, part_number FROM products
             WHERE manufacturer_id = ? AND TRIM(LOWER(part_number)) = ?
             ORDER BY id ASC''',
          [manufacturerId, partClean],
        );

        if (productRows.length <= 1) continue;

        final keepId = productRows.first['id'] as int;
        final dupIds = productRows.skip(1).map((r) => r['id'] as int).toList();

        print(
          'Merging part "$partClean" for manufacturer $manufacturerId => keep id $keepId, duplicates: ${dupIds.join(', ')}',
        );

        for (final dupId in dupIds) {
          // Reassign product_images
          await txn.rawUpdate(
            'UPDATE product_images SET product_id = ? WHERE product_id = ?',
            [keepId, dupId],
          );

          // Reassign product_inventory
          await txn.rawUpdate(
            'UPDATE product_inventory SET product_id = ? WHERE product_id = ?',
            [keepId, dupId],
          );

          // Reassign product_compatibility
          await txn.rawUpdate(
            'UPDATE product_compatibility SET product_id = ? WHERE product_id = ?',
            [keepId, dupId],
          );

          // Update customer_bills items JSON: replace occurrences of dupId -> keepId
          final bills = await txn.rawQuery(
            'SELECT id, items FROM customer_bills',
          );
          for (final b in bills) {
            final billId = b['id'] as int;
            final itemsRaw = b['items'] as String?;
            if (itemsRaw == null || itemsRaw.isEmpty) continue;
            bool changed = false;
            try {
              final items = jsonDecode(itemsRaw) as List<dynamic>;
              for (final it in items) {
                if (it is Map && it['product_id'] == dupId) {
                  it['product_id'] = keepId;
                  changed = true;
                }
              }
              if (changed) {
                final newItems = jsonEncode(items);
                await txn.update(
                  'customer_bills',
                  {'items': newItems},
                  where: 'id = ?',
                  whereArgs: [billId],
                );
                print(
                  '  - Updated bill $billId: replaced product $dupId -> $keepId',
                );
              }
            } catch (e) {
              // If parsing fails, skip but log
              print('  ! Failed to parse items for bill $billId: $e');
            }
          }

          // Finally delete the duplicate product row
          await txn.delete('products', where: 'id = ?', whereArgs: [dupId]);
          print('  - Deleted duplicate product id $dupId');
        }
      }
    });

    print('Deduplication completed.');
    print('IMPORTANT: Review app behavior and run a backup/verification.');
  } finally {
    await db.close();
  }
}
