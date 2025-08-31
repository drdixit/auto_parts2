import 'package:flutter/material.dart';
import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/models/customer.dart';
import 'package:auto_parts2/theme/app_colors.dart';
import 'package:auto_parts2/screens/customers/customer_bills_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerService _service = CustomerService();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _customers = await _service.getAllCustomers();
    setState(() => _loading = false);
  }

  double get _totalUnpaid =>
      _customers.fold(0.0, (s, c) => s + (c.balance < 0 ? -c.balance : 0.0));

  Future<void> _showEdit(Customer? c) async {
    final nameCtrl = TextEditingController(text: c?.name ?? '');
    final addrCtrl = TextEditingController(text: c?.address ?? '');
    final mobileCtrl = TextEditingController(text: c?.mobile ?? '');
    final openingCtrl = TextEditingController(
      text: (c?.openingBalance ?? 0).toString(),
    );

    final saved = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c == null ? 'Create Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextField(
                controller: mobileCtrl,
                decoration: const InputDecoration(labelText: 'Mobile'),
              ),
              TextField(
                controller: openingCtrl,
                decoration: const InputDecoration(labelText: 'Opening Balance'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final navigator = Navigator.of(context);
              final cust = Customer(
                id: c?.id,
                name: nameCtrl.text.trim(),
                address: addrCtrl.text.trim(),
                mobile: mobileCtrl.text.trim(),
                openingBalance: double.tryParse(openingCtrl.text) ?? 0.0,
                balance:
                    c?.balance ?? (double.tryParse(openingCtrl.text) ?? 0.0),
              );
              if (c == null) {
                await _service.createCustomer(cust);
              } else {
                await _service.updateCustomer(cust);
              }
              navigator.pop(true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) await _load();
  }

  Future<void> _delete(Customer c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer?'),
        content: Text('Delete ${c.name}? This will remove all related bills.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteCustomer(c.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Customers',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showEdit(null),
                icon: const Icon(Icons.person_add),
                label: const Text('New'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_loading)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet),
                    const SizedBox(width: 8),
                    Text(
                      'Total unpaid across customers: ',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${_totalUnpaid.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _customers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = _customers[i];
                      final balanceColor = c.balance < 0
                          ? AppColors.error
                          : AppColors.textSecondary;
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Row(
                          children: [
                            Expanded(child: Text(c.mobile ?? '')),
                            if (c.balance != 0.0)
                              Text(
                                'Balance: ₹${c.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: balanceColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.receipt_long),
                              tooltip: 'View bills',
                              onPressed: () async {
                                // open bills screen filtered to this customer
                                final navigator = Navigator.of(context);
                                await navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerBillsScreen(customerId: c.id),
                                  ),
                                );
                                if (!mounted) return;
                                await _load();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEdit(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _delete(c),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
