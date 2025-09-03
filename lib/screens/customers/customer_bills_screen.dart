import 'package:flutter/material.dart';
import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/services/product_service.dart';
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
    // Load all bills (recent first). We'll render them in a table and allow
    // toggling paid/unpaid status from here.
    _bills = await _service.getCustomerBills(customerId: widget.customerId);
    // Ensure last-created bill shows first (defensive: sort by created_at desc)
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
        return -1; // a has date, b doesn't -> a is newer, so a before b
      } else if (bDt != null) {
        return 1; // b has date, a doesn't -> b before a
      }

      // Fallback: compare by id descending (last inserted id first)
      final aid = (a['id'] is int)
          ? a['id'] as int
          : int.tryParse('${a['id']}') ?? 0;
      final bid = (b['id'] is int)
          ? b['id'] as int
          : int.tryParse('${b['id']}') ?? 0;
      return bid.compareTo(aid);
    });
    // load inventory/cost info lazily when building UI
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
      final dt = DateTime.parse(iso).toLocal();
      // e.g. 12 Jan 2025
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

  Future<void> _showBillDetails(Map<String, dynamic> bill) async {
    final items = (bill['items'] as List).cast<Map<String, dynamic>>();
    // Build lines for display using product names
    final BuildContext dialogContext = context;
    await showDialog<void>(
      context: dialogContext,
      builder: (ctx) {
        final isPaid = (bill['is_paid'] ?? false) as bool;
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
                      const Expanded(
                        child: Text(
                          'Estimate',
                          style: TextStyle(
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
                            // Lines
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
                        child: OutlinedButton(
                          onPressed: () async {
                            // Capture navigator from the dialog context before awaiting
                            final navigator = Navigator.of(ctx);
                            // Toggle paid state
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
    // Provide a Scaffold so this screen can be closed safely when pushed or shown as a page.
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.customerId != null
                ? 'Bills — ${_custName(widget.customerId!)}'
                : 'Customer Bills',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customerId != null
              ? 'Bills — ${_custName(widget.customerId!)}'
              : 'Customer Bills',
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
                      Text(
                        'Customer Bills',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Bill #')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Actions')),
                              DataColumn(label: Text('Details')),
                            ],
                            rows: _bills.map((b) {
                              final isPaid = (b['is_paid'] ?? false) as bool;
                              final total = (b['total'] as double);
                              return DataRow(
                                cells: [
                                  DataCell(Text('${b['id']}')),
                                  DataCell(
                                    Text(
                                      _formatDate(b['created_at'] as String?),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_custName(b['customer_id'] as int)),
                                  ),
                                  DataCell(
                                    Text(
                                      '₹${total.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isPaid
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton(
                                      onPressed: () async {
                                        await _markPaid(b, !isPaid);
                                      },
                                      child: Text(isPaid ? 'Unpaid' : 'Paid'),
                                    ),
                                  ),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => _showBillDetails(b),
                                      child: const Text('See'),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
