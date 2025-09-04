import 'package:flutter/material.dart';
import 'package:auto_parts2/theme/app_colors.dart';

/// Small DTO used by the dialog to keep logic separate from POS models.
class InvoiceLine {
  final String name;
  final int qty;
  final double unitPrice;
  final String? location; // optional RAC/Location from inventory

  InvoiceLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.location,
  });

  double get lineTotal => qty * unitPrice;
}

class DummyInvoiceDialog extends StatefulWidget {
  final List<InvoiceLine> lines;
  final VoidCallback? onCreated;
  // optional pre-selected customer to display
  final dynamic customer;

  const DummyInvoiceDialog({
    super.key,
    required this.lines,
    this.onCreated,
    this.customer,
  });

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer summary (show either passed customer or editable fields)
              Card(
                elevation: 0,
                color: Colors.transparent,
                shadowColor: Colors.transparent,
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
                      if (widget.customer != null) ...[
                        // customer may be a Map or an object with fields
                        Text(
                          widget.customer is Map
                              ? (widget.customer['name'] ?? '').toString()
                              : widget.customer.name ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.customer is Map
                              ? (widget.customer['address'] ?? '').toString()
                              : (widget.customer.address ?? ''),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.customer is Map
                              ? (widget.customer['mobile'] ?? '').toString()
                              : (widget.customer.mobile ?? ''),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ] else ...[
                        TextField(
                          controller: _customerName,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customerAddress,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
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
                        // Header (show timestamp)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
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

                        // Customer summary: prefer passed customer, else use typed fields
                        if (widget.customer != null ||
                            _customerName.text.isNotEmpty ||
                            _customerContact.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(text: 'To: '),
                                  TextSpan(
                                    text: widget.customer != null
                                        ? (widget.customer is Map
                                              ? (widget.customer['name'] ?? '')
                                              : (widget.customer.name ?? ''))
                                        : _customerName.text,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: widget.customer != null
                                        ? ((widget.customer is Map
                                                          ? (widget.customer['mobile'] ??
                                                                '')
                                                          : (widget
                                                                    .customer
                                                                    .mobile ??
                                                                '')) !=
                                                      ''
                                                  ? ' • ${(widget.customer is Map ? (widget.customer['mobile'] ?? '') : (widget.customer.mobile ?? ''))}'
                                                  : '') +
                                              '\n${widget.customer is Map ? (widget.customer['address'] ?? '') : (widget.customer.address ?? '')}'
                                        : (_customerContact.text.isNotEmpty
                                                  ? ' \u2022 ${_customerContact.text}'
                                                  : '') +
                                              '\n${_customerAddress.text}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const Divider(),

                        // Lines: single row per item
                        Expanded(
                          child: ListView.separated(
                            itemCount: widget.lines.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 8),
                            itemBuilder: (context, i) {
                              final l = widget.lines[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Name + inline location
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(
                                            context,
                                          ).style,
                                          children: [
                                            TextSpan(text: l.name),
                                            if (l.location != null &&
                                                l.location!.isNotEmpty) ...[
                                              const TextSpan(text: ' • '),
                                              TextSpan(
                                                text: l.location!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                    // qty x
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        '${l.qty} x',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // single unit price
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        '\u20b9${l.unitPrice.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // line total
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        '\u20b9${l.lineTotal.toStringAsFixed(2)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                              '\u20b9${_total.toStringAsFixed(2)}',
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
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.lines.isEmpty
                          ? null
                          : () {
                              // Create as unpaid invoice
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Estimate created - Unpaid'),
                                ),
                              );
                              if (widget.onCreated != null) widget.onCreated!();
                              Navigator.of(context).pop(false);
                            },
                      child: const Text('Unpaid'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.lines.isEmpty
                          ? null
                          : () {
                              // Create as paid invoice
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Estimate created - Paid'),
                                ),
                              );
                              if (widget.onCreated != null) widget.onCreated!();
                              Navigator.of(context).pop(true);
                            },
                      child: const Text('Paid'),
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
