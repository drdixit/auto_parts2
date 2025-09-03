import 'package:flutter/material.dart';
import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/services/product_service.dart';
import 'package:auto_parts2/utils/bill_utils.dart';
import 'package:auto_parts2/models/customer.dart';

class CustomerBillsScreen extends StatefulWidget {
  final int? customerId;

  const CustomerBillsScreen({super.key, this.customerId});

  @override
  State<CustomerBillsScreen> createState() => _CustomerBillsScreenState();
}

class _CustomerBillsScreenState extends State<CustomerBillsScreen> {
  final CustomerService _service = CustomerService();
  final ProductService _productService = ProductService();
  List<Map<String, dynamic>> _bills = [];
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _customers = await _service.getAllCustomers();
    _bills = await _service.getCustomerBills(customerId: widget.customerId);

    // Prefer created_at descending; fallback to id descending
    _bills.sort((a, b) {
      DateTime? parseSafe(dynamic v) {
        if (v == null) return null;
        try {
          return DateTime.parse(v.toString()).toUtc();
        } catch (_) {
          return null;
        }
      }

      final aDt = parseSafe(a['created_at']);
      final bDt = parseSafe(b['created_at']);
      if (aDt != null && bDt != null) {
        final cmp = bDt.compareTo(aDt);
        if (cmp != 0) return cmp;
      } else if (aDt != null) {
        return -1;
      } else if (bDt != null) {
        return 1;
      }

      final aid = (a['id'] is int)
          ? a['id'] as int
          : int.tryParse('${a['id']}') ?? 0;
      final bid = (b['id'] is int)
          ? b['id'] as int
          : int.tryParse('${b['id']}') ?? 0;
      return bid.compareTo(aid);
    });

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<String> _productName(int? pid) async {
    if (pid == null) return 'Unknown product';
    final p = await _productService.getProductById(pid);
    return p?.name ?? 'Unknown product';
  }

  String _custName(int id) {
    final c = _customers.firstWhere(
      (x) => x.id == id,
      orElse: () => Customer(name: '', address: '', mobile: ''),
    );
    return c.name;
  }

  Future<void> _markPaid(Map<String, dynamic> bill, bool toPaid) async {
    await _service.markBillPaid(bill['id'] as int, paid: toPaid);
    await _load();
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      // Handle SQLite CURRENT_TIMESTAMP which is 'YYYY-MM-DD HH:MM:SS' (UTC without timezone).
      // If we parse that directly, DateTime.parse treats it as local which makes toLocal() incorrect.
      // Normalize space-separated UTC timestamps to ISO + 'Z' so parsing yields UTC, then convert to local.
      final sqliteSpaceTs = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\$');
      final normalized = sqliteSpaceTs.hasMatch(iso)
          ? iso.replaceFirst(' ', 'T') + 'Z'
          : iso;
      final dt = DateTime.parse(normalized).toLocal();
      final m = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (e) {
      return iso.split('T').first;
    }
  }

  // Compare bills so newest (by created_at) comes first; fallback to id desc
  int _compareBills(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime? parseSafe(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toUtc();
      } catch (_) {
        return null;
      }
    }

    final aDt = parseSafe(a['created_at']);
    final bDt = parseSafe(b['created_at']);
    if (aDt != null && bDt != null) {
      final cmp = bDt.compareTo(aDt);
      if (cmp != 0) return cmp;
    } else if (aDt != null) {
      return -1;
    } else if (bDt != null) {
      return 1;
    }

    final aid = (a['id'] is int)
        ? a['id'] as int
        : int.tryParse('${a['id']}') ?? 0;
    final bid = (b['id'] is int)
        ? b['id'] as int
        : int.tryParse('${b['id']}') ?? 0;
    return bid.compareTo(aid);
  }

  Future<void> _showBillDetails(Map<String, dynamic> bill) async {
    final items = (bill['items'] as List).cast<Map<String, dynamic>>();
    final BuildContext dialogContext = context;
    await showDialog<void>(
      context: dialogContext,
      builder: (ctx) {
        final bool isPaid = bill['is_paid'] == true;
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Estimate-${formatBillCode(bill['id'], bill['created_at'] as String?)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(_custName(bill['customer_id'] as int)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            const Divider(),
                            Expanded(
                              child: ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 8),
                                itemBuilder: (context, i) {
                                  final line = items[i];
                                  return FutureBuilder<String>(
                                    future: _productName(
                                      line['product_id'] as int?,
                                    ),
                                    builder: (context, snap) {
                                      final pname = snap.data ?? 'Product';
                                      final qty = (line['qty'] as int?) ?? 1;
                                      final lt =
                                          (line['line_total'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      return Row(
                                        children: [
                                          Expanded(child: Text(pname)),
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              '$qty x',
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              '₹${lt.toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '₹${(bill['total'] as double).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            await _markPaid(bill, !isPaid);
                            if (mounted) navigator.pop();
                          },
                          child: Text(isPaid ? 'Unpaid' : 'Paid'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.customerId != null
                ? 'Estimates — ${_custName(widget.customerId!)}'
                : 'Customer Estimates',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customerId != null
              ? 'Estimates — ${_custName(widget.customerId!)}'
              : 'Customer Estimates',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            if (widget.customerId != null)
              Builder(
                builder: (context) {
                  final cust = _customers.firstWhere(
                    (c) => c.id == widget.customerId,
                    orElse: () => Customer(name: '', address: '', mobile: ''),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet),
                        const SizedBox(width: 8),
                        Text(
                          'Opening balance: ',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '₹${cust.openingBalance.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cust.openingBalance < 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header intentionally removed (replaced by AppBar title)
                      const SizedBox(height: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final sorted = [..._bills];
                            sorted.sort(_compareBills);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: SingleChildScrollView(
                                  child: DataTable(
                                    columnSpacing: 24,
                                    columns: const [
                                      DataColumn(label: Text('Estimates No')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Customer')),
                                      DataColumn(label: Text('Total')),
                                      DataColumn(label: Text('Actions')),
                                      DataColumn(label: Text('Details')),
                                    ],
                                    rows: sorted.map((b) {
                                      final isPaid =
                                          (b['is_paid'] ?? false) as bool;
                                      final total = (b['total'] as double);
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(
                                              formatBillCode(
                                                b['id'],
                                                b['created_at'] as String?,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _formatDate(
                                                b['created_at'] as String?,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              _custName(
                                                b['customer_id'] as int,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '₹${total.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isPaid
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TextButton(
                                              onPressed: () async {
                                                await _markPaid(b, !isPaid);
                                              },
                                              child: Text(
                                                isPaid ? 'Unpaid' : 'Paid',
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            TextButton(
                                              onPressed: () =>
                                                  _showBillDetails(b),
                                              child: const Text('See'),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
