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
  List<Map<String, dynamic>> _unpaid = [];
  List<Map<String, dynamic>> _paid = [];
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _customers = await _service.getAllCustomers();
    _unpaid = await _service.getCustomerBills(
      isPaid: false,
      customerId: widget.customerId,
    );
    _paid = await _service.getCustomerBills(
      isPaid: true,
      customerId: widget.customerId,
    );
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
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _customers.length,
                                itemBuilder: (context, ci) {
                                  final cust = _customers[ci];
                                  final custUnpaid = _unpaid
                                      .where((b) => b['customer_id'] == cust.id)
                                      .toList();
                                  if (custUnpaid.isEmpty) {
                                    return const SizedBox();
                                  }
                                  final balance = cust.balance;
                                  return ExpansionTile(
                                    title: Text(
                                      balance < 0
                                          ? '${cust.name} — owes ₹${(-balance).toStringAsFixed(2)}'
                                          : cust.name,
                                    ),
                                    children: custUnpaid.map((b) {
                                      final items = (b['items'] as List)
                                          .cast<Map<String, dynamic>>();
                                      return ExpansionTile(
                                        title: Text(
                                          'Bill ${b['id']} — ₹${(b['total'] as double).toStringAsFixed(2)}',
                                        ),
                                        subtitle: Text(
                                          '${b['created_at'] ?? ''}',
                                        ),
                                        children: [
                                          ...items.map(
                                            (line) => FutureBuilder<String>(
                                              future: _productName(
                                                line['product_id'] as int?,
                                              ),
                                              builder: (context, snap) {
                                                final pname =
                                                    snap.data ?? 'Product';
                                                final qty =
                                                    (line['qty'] as int?) ?? 1;
                                                final lt =
                                                    (line['line_total'] as num?)
                                                        ?.toDouble() ??
                                                    0.0;
                                                return ListTile(
                                                  title: Text('$pname x $qty'),
                                                  subtitle: Text(
                                                    '₹${lt.toStringAsFixed(2)}',
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          OverflowBar(
                                            spacing: 8,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _markPaid(b, true),
                                                child: const Text('Mark Paid'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paid',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _paid.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final b = _paid[i];
                                  return ListTile(
                                    title: Text(
                                      '${_custName(b['customer_id'])} - ₹${(b['total'] as double).toStringAsFixed(2)}',
                                    ),
                                    subtitle: Text(
                                      '${(b['items'] as List).length} items • ${b['created_at'] ?? ''}',
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => _markPaid(b, false),
                                      child: const Text('Mark Unpaid'),
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
          ],
        ),
      ),
    );
  }
}
