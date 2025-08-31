import 'dart:convert';
import 'package:auto_parts2/database/database_helper.dart';
import 'package:auto_parts2/models/customer.dart';

class CustomerService {
  final _dbHelper = DatabaseHelper();

  Future<int> createCustomer(Customer c) async {
    final db = await _dbHelper.database;
    // Normalize opening balance: positive input => store as negative (they owe us)
    double newOpening = c.openingBalance;
    if (newOpening > 0) newOpening = -newOpening.abs();
    c.openingBalance = newOpening;
    // For a new customer, initialize balance to the opening balance
    c.balance = newOpening;
    final id = await db.insert('customers', c.toMap());
    return id;
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await _dbHelper.database;
    final rows = await db.query('customers', orderBy: 'name');
    return rows.map((r) => Customer.fromMap(r)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<int> updateCustomer(Customer c) async {
    final db = await _dbHelper.database;
    // Perform update inside a transaction so we can adjust balance consistently when opening_balance changes
    return await db.transaction<int>((txn) async {
      // fetch existing opening_balance
      final rows = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [c.id],
      );
      if (rows.isEmpty) return 0;
      final oldOpeningNum = rows.first['opening_balance'];
      final oldOpening = (oldOpeningNum is num)
          ? oldOpeningNum.toDouble()
          : (double.tryParse(oldOpeningNum?.toString() ?? '') ?? 0.0);

      // Normalize new opening: positive input -> negative
      double newOpening = c.openingBalance;
      if (newOpening > 0) newOpening = -newOpening.abs();

      final delta =
          newOpening -
          oldOpening; // how much opening changed (can be positive or negative)

      // Update core fields and opening_balance; adjust balance separately using SQL math
      final data = {
        'name': c.name,
        'address': c.address,
        'mobile': c.mobile,
        'opening_balance': newOpening,
      };

      final count = await txn.update(
        'customers',
        data,
        where: 'id = ?',
        whereArgs: [c.id],
      );
      if (count > 0 && delta != 0) {
        // Apply delta to balance so balance stays consistent with change in opening balance
        await txn.rawUpdate(
          'UPDATE customers SET balance = COALESCE(balance, 0) + ? WHERE id = ?',
          [delta, c.id],
        );
      }
      return count;
    });
  }

  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // Bills
  Future<int> createCustomerBill({
    required int customerId,
    required List<Map<String, dynamic>> items,
    required double total,
    bool isPaid = false,
  }) async {
    final db = await _dbHelper.database;
    final payload = jsonEncode(items);
    // Run in a transaction: insert bill and update customer balance if unpaid
    return await db.transaction<int>((txn) async {
      final id = await txn.insert('customer_bills', {
        'customer_id': customerId,
        'items': payload,
        'total': total,
        'is_paid': isPaid ? 1 : 0,
        'is_held': 0,
      });
      if (!isPaid) {
        // Decrease customer's balance by total (they owe money)
        await txn.rawUpdate(
          'UPDATE customers SET balance = COALESCE(balance, 0) - ? WHERE id = ?',
          [total, customerId],
        );
      }
      return id;
    });
  }

  // Held bills: create a persisted hold (is_held = 1). Held bills do not affect customer balance until finalized as invoices.
  Future<int> createHeldBill({
    required int customerId,
    required List<Map<String, dynamic>> items,
    required double total,
  }) async {
    final db = await _dbHelper.database;
    final payload = jsonEncode(items);
    return await db.insert('customer_bills', {
      'customer_id': customerId,
      'items': payload,
      'total': total,
      'is_paid': 0,
      'is_held': 1,
    });
  }

  Future<List<Map<String, dynamic>>> getHeldBills({int? customerId}) async {
    final db = await _dbHelper.database;
    final where = <String>['is_held = 1'];
    final args = <dynamic>[];
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    final rows = await db.query(
      'customer_bills',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      final totalVal = r['total'];
      double total = 0.0;
      if (totalVal is num) {
        total = totalVal.toDouble();
      } else if (totalVal is String) {
        total = double.tryParse(totalVal) ?? 0.0;
      }

      return {
        'id': r['id'],
        'customer_id': r['customer_id'],
        'items': jsonDecode(r['items'] as String),
        'total': total,
        'is_paid': (r['is_paid'] ?? 0) == 1,
        'is_held': (r['is_held'] ?? 0) == 1,
        'created_at': r['created_at'],
      };
    }).toList();
  }

  // Finalize a held bill: mark is_held=0 and optionally mark as paid/unpaid. If marking unpaid (invoice created), adjust customer balance.
  Future<int> finalizeHeldBill(int holdId, {bool markPaid = false}) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      final rows = await txn.query(
        'customer_bills',
        where: 'id = ? AND is_held = 1',
        whereArgs: [holdId],
      );
      if (rows.isEmpty) return 0;
      final bill = rows.first;
      final customerId = bill['customer_id'] as int;
      final totalVal = bill['total'];
      double total = 0.0;
      if (totalVal is num) {
        total = totalVal.toDouble();
      } else if (totalVal is String) {
        total = double.tryParse(totalVal) ?? 0.0;
      }

      final count = await txn.update(
        'customer_bills',
        {'is_held': 0, 'is_paid': markPaid ? 1 : 0},
        where: 'id = ?',
        whereArgs: [holdId],
      );

      if (count > 0 && !markPaid) {
        // It becomes an unpaid invoice; adjust customer balance
        await txn.rawUpdate(
          'UPDATE customers SET balance = COALESCE(balance, 0) - ? WHERE id = ?',
          [total, customerId],
        );
      } else if (count > 0 && markPaid) {
        // If marking as paid at finalize time, ensure customer's balance increases (they don't owe)
        await txn.rawUpdate(
          'UPDATE customers SET balance = COALESCE(balance, 0) + ? WHERE id = ?',
          [total, customerId],
        );
      }
      return count;
    });
  }

  Future<List<Map<String, dynamic>>> getCustomerBills({
    int? customerId,
    bool? isPaid,
  }) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <dynamic>[];
    if (customerId != null) {
      where.add('customer_id = ?');
      args.add(customerId);
    }
    if (isPaid != null) {
      where.add('is_paid = ?');
      args.add(isPaid ? 1 : 0);
    }
    final rows = await db.query(
      'customer_bills',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) {
      final totalVal = r['total'];
      double total = 0.0;
      if (totalVal is num) {
        total = totalVal.toDouble();
      } else if (totalVal is String) {
        total = double.tryParse(totalVal) ?? 0.0;
      }

      return {
        'id': r['id'],
        'customer_id': r['customer_id'],
        'items': jsonDecode(r['items'] as String),
        'total': total,
        'is_paid': (r['is_paid'] ?? 0) == 1,
        'created_at': r['created_at'],
      };
    }).toList();
  }

  Future<int> markBillPaid(int billId, {bool paid = true}) async {
    final db = await _dbHelper.database;
    return await db.transaction<int>((txn) async {
      // find bill
      final rows = await txn.query(
        'customer_bills',
        where: 'id = ?',
        whereArgs: [billId],
      );
      if (rows.isEmpty) return 0;
      final bill = rows.first;
      final customerId = bill['customer_id'] as int;
      final totalVal = bill['total'];
      double total = 0.0;
      if (totalVal is num) {
        total = totalVal.toDouble();
      } else if (totalVal is String) {
        total = double.tryParse(totalVal) ?? 0.0;
      }

      // update bill paid flag
      final count = await txn.update(
        'customer_bills',
        {'is_paid': paid ? 1 : 0},
        where: 'id = ?',
        whereArgs: [billId],
      );

      if (count > 0) {
        // adjust customer balance: if paid -> increase balance by total (they no longer owe); if marking unpaid -> decrease
        if (paid) {
          await txn.rawUpdate(
            'UPDATE customers SET balance = COALESCE(balance, 0) + ? WHERE id = ?',
            [total, customerId],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE customers SET balance = COALESCE(balance, 0) - ? WHERE id = ?',
            [total, customerId],
          );
        }
      }
      return count;
    });
  }

  Future<int> deleteHeldBill(int holdId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'customer_bills',
      where: 'id = ? AND is_held = 1',
      whereArgs: [holdId],
    );
  }
}
