import 'package:flutter/material.dart';
import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/services/product_service.dart';
import 'package:auto_parts2/utils/bill_utils.dart';
import 'package:auto_parts2/models/customer.dart';
import 'package:auto_parts2/models/product_inventory.dart';

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
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _filterQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      // Format as DD/MM/YYYY with zero-padded day and month
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      return '$dd/$mm/$yyyy';
    } catch (e) {
      // Fallback: try to extract date part in YYYY-MM-DD and convert to DD/MM/YYYY
      try {
        final part = iso.split('T').first;
        final parts = part.split('-');
        if (parts.length >= 3) {
          final y = parts[0];
          final m = parts[1].padLeft(2, '0');
          final d = parts[2].padLeft(2, '0');
          return '$d/$m/$y';
        }
      } catch (_) {}
      return iso;
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
        // defensive: try to find the customer object
        final custObj = _customers.firstWhere(
          (c) => c.id == (bill['customer_id'] as int),
          orElse: () => Customer(name: '', address: '', mobile: ''),
        );
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: Colors.transparent,
                    shadowColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header and bold name
                          Row(
                            children: [
                              const Text(
                                'Customer - ',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Expanded(
                                child: Text(
                                  custObj.name.isNotEmpty
                                      ? custObj.name
                                      : _custName(bill['customer_id'] as int),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            custObj.mobile ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            custObj.address ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
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
                                  final pid = line['product_id'] as int?;
                                  final combined = Future.wait<dynamic>([
                                    _productName(pid),
                                    _productService.getProductInventory(
                                      pid ?? 0,
                                    ),
                                  ]);

                                  return FutureBuilder<List<dynamic>>(
                                    future: combined,
                                    builder: (context, snap) {
                                      final pname =
                                          (snap.data != null &&
                                              snap.data!.isNotEmpty)
                                          ? (snap.data![0] as String?) ??
                                                'Product'
                                          : 'Product';
                                      final inv =
                                          (snap.data != null &&
                                              snap.data!.length > 1)
                                          ? snap.data![1]
                                          : null;

                                      final qty = (line['qty'] as int?) ?? 1;
                                      final lt =
                                          (line['line_total'] as num?)
                                              ?.toDouble() ??
                                          0.0;

                                      // Extract location defensively — inventory may be a Map or a model
                                      String? loc;
                                      try {
                                        if (inv != null) {
                                          if (inv is ProductInventory) {
                                            loc = inv.locationRack?.trim();
                                          } else if (inv is Map) {
                                            loc =
                                                (inv['location_rack']
                                                        as String?)
                                                    ?.trim();
                                          } else {
                                            // last resort: attempt dynamic access
                                            try {
                                              final lr =
                                                  (inv as dynamic).locationRack;
                                              loc = (lr as String?)?.trim();
                                            } catch (_) {
                                              loc = null;
                                            }
                                          }
                                        }
                                      } catch (_) {
                                        loc = null;
                                      }

                                      return Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    pname,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (loc != null &&
                                                    loc.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      loc,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 60,
                                            child: Text(
                                              '${qty} x',
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
                      // Search bar for filtering estimates by customer name or estimate number
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText:
                                      'Search by customer name or estimate no',
                                  suffixIcon: _filterQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Apply filtering
                            final lower = _filterQuery.toLowerCase();
                            final filtered = _filterQuery.isEmpty
                                ? _bills
                                : _bills.where((b) {
                                    final idStr = '${b['id'] ?? ''}';
                                    final createdAt =
                                        b['created_at'] as String?;
                                    final formatted = formatBillCode(
                                      b['id'],
                                      createdAt,
                                    ).toLowerCase();
                                    final custName = (b['customer_id'] != null)
                                        ? _custName(
                                            b['customer_id'] as int,
                                          ).toLowerCase()
                                        : '';
                                    return idStr.toLowerCase().contains(
                                          lower,
                                        ) ||
                                        formatted.contains(lower) ||
                                        custName.contains(lower);
                                  }).toList();
                            final sorted = [...filtered];
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
                                    columns: [
                                      DataColumn(
                                        label: Text(
                                          'Estimates No',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Date',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Customer',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Total',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Status',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Actions',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Share',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Credit Note',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: sorted.map((b) {
                                      final isPaid =
                                          (b['is_paid'] ?? false) as bool;
                                      final total = (b['total'] as double);
                                      return DataRow(
                                        cells: [
                                          // Estimates No
                                          DataCell(
                                            Text(
                                              formatBillCode(
                                                b['id'],
                                                b['created_at'] as String?,
                                              ),
                                            ),
                                          ),
                                          // Date
                                          DataCell(
                                            Text(
                                              _formatDate(
                                                b['created_at'] as String?,
                                              ),
                                            ),
                                          ),
                                          // Customer
                                          DataCell(
                                            Text(
                                              _custName(
                                                b['customer_id'] as int,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          // Total
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
                                          // Status (Paid/Unpaid)
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
                                          // Actions (view)
                                          DataCell(
                                            TextButton(
                                              onPressed: () =>
                                                  _showBillDetails(b),
                                              child: const Icon(
                                                Icons.visibility,
                                              ),
                                            ),
                                          ),
                                          // Share
                                          DataCell(
                                            TextButton(
                                              onPressed: () {},
                                              child: const Icon(Icons.share),
                                            ),
                                          ),
                                          // Credit Note (dummy)
                                          DataCell(
                                            IconButton(
                                              onPressed: () {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Create credit note — TODO',
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.note_add),
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
