import 'package:flutter/material.dart';
import 'package:auto_parts2/theme/app_colors.dart';

/// Small DTO used by the dialog to keep logic separate from POS models.
class InvoiceLine {
  final String name;
  final int qty;
  final double unitPrice;

  InvoiceLine({required this.name, required this.qty, required this.unitPrice});

  double get lineTotal => qty * unitPrice;
}

class DummyInvoiceDialog extends StatefulWidget {
  final List<InvoiceLine> lines;
  final VoidCallback? onCreated;

  const DummyInvoiceDialog({super.key, required this.lines, this.onCreated});

  @override
  State<DummyInvoiceDialog> createState() => _DummyInvoiceDialogState();
}

class _DummyInvoiceDialogState extends State<DummyInvoiceDialog> {
  final TextEditingController _customerName = TextEditingController();
  final TextEditingController _customerAddress = TextEditingController();
  final TextEditingController _customerContact = TextEditingController();

  double get _total => widget.lines.fold(0.0, (s, l) => s + l.lineTotal);

  @override
  void dispose() {
    _customerName.dispose();
    _customerAddress.dispose();
    _customerContact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Create Invoice (Dummy)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer form (temporary variables)
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
                      TextField(
                        controller: _customerName,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customerAddress,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customerContact,
                        decoration: const InputDecoration(
                          labelText: 'Contact Number',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Invoice preview
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Auto Parts (Dummy Invoice)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${DateTime.now()}'.split('.')[0],
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.surfaceMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Customer summary
                        if (_customerName.text.isNotEmpty ||
                            _customerContact.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'To: ${_customerName.text} ${_customerContact.text.isNotEmpty ? '• ${_customerContact.text}' : ''}\n${_customerAddress.text}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        const Divider(),
                        // Lines
                        Expanded(
                          child: ListView.separated(
                            itemCount: widget.lines.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final l = widget.lines[i];
                              return Row(
                                children: [
                                  Expanded(child: Text(l.name)),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${l.qty} x',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      '₹${l.lineTotal.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const Divider(),
                        // Totals
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '₹${_total.toStringAsFixed(2)}',
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.lines.isEmpty
                          ? null
                          : () {
                              // Temporary behavior: show a snackbar and notify caller via callback.
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invoice created (dummy)'),
                                ),
                              );
                              if (widget.onCreated != null) widget.onCreated!();
                              Navigator.of(context).pop();
                            },
                      child: const Text('Create Invoice'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
