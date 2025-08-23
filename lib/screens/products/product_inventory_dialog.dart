import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/product_inventory.dart';
import '../../services/product_service.dart';

class ProductInventoryDialog extends StatefulWidget {
  final int productId;
  final String productName;
  final ProductInventory? inventory;

  const ProductInventoryDialog({
    super.key,
    required this.productId,
    required this.productName,
    this.inventory,
  });

  bool get isEditing => inventory != null;

  @override
  State<ProductInventoryDialog> createState() => _ProductInventoryDialogState();
}

class _ProductInventoryDialogState extends State<ProductInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  // Form controllers
  final _supplierNameController = TextEditingController();
  final _supplierContactController = TextEditingController();
  final _supplierEmailController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _mrpController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _maximumStockController = TextEditingController();
  final _locationRackController = TextEditingController();

  // State
  bool _isLoading = false;
  bool _isActive = true;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierContactController.dispose();
    _supplierEmailController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _stockQuantityController.dispose();
    _minimumStockController.dispose();
    _maximumStockController.dispose();
    _locationRackController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.inventory != null) {
      final inventory = widget.inventory!;
      _supplierNameController.text = inventory.supplierName ?? '';
      _supplierContactController.text = inventory.supplierContact ?? '';
      _supplierEmailController.text = inventory.supplierEmail ?? '';
      _costPriceController.text = inventory.costPrice.toString();
      _sellingPriceController.text = inventory.sellingPrice.toString();
      _mrpController.text = inventory.mrp.toString();
      _stockQuantityController.text = inventory.stockQuantity.toString();
      _minimumStockController.text = inventory.minimumStockLevel.toString();
      _maximumStockController.text = inventory.maximumStockLevel.toString();
      _locationRackController.text = inventory.locationRack ?? '';
      _isActive = inventory.isActive;
    } else {
      // Default values for new inventory
      _costPriceController.text = '0.00';
      _sellingPriceController.text = '0.00';
      _mrpController.text = '0.00';
      _stockQuantityController.text = '0';
      _minimumStockController.text = '5';
      _maximumStockController.text = '100';
    }
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clear();
    });

    try {
      // Parse numeric values
      final costPrice =
          double.tryParse(_costPriceController.text.trim()) ?? 0.0;
      final sellingPrice =
          double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
      final mrp = double.tryParse(_mrpController.text.trim()) ?? 0.0;
      final stockQuantity =
          int.tryParse(_stockQuantityController.text.trim()) ?? 0;
      final minStock = int.tryParse(_minimumStockController.text.trim()) ?? 5;
      final maxStock = int.tryParse(_maximumStockController.text.trim()) ?? 100;

      // Validate price relationships
      if (sellingPrice > 0 && costPrice > sellingPrice) {
        setState(() {
          _fieldErrors['cost_price'] =
              'Cost price cannot be higher than selling price';
          _isLoading = false;
        });
        return;
      }

      if (mrp > 0 && sellingPrice > mrp) {
        setState(() {
          _fieldErrors['selling_price'] =
              'Selling price cannot be higher than MRP';
          _isLoading = false;
        });
        return;
      }

      if (minStock > maxStock) {
        setState(() {
          _fieldErrors['minimum_stock'] =
              'Minimum stock cannot be higher than maximum stock';
          _isLoading = false;
        });
        return;
      }

      final inventory = ProductInventory(
        id: widget.inventory?.id,
        productId: widget.productId,
        supplierName: _supplierNameController.text.trim().isEmpty
            ? null
            : _supplierNameController.text.trim(),
        supplierContact: _supplierContactController.text.trim().isEmpty
            ? null
            : _supplierContactController.text.trim(),
        supplierEmail: _supplierEmailController.text.trim().isEmpty
            ? null
            : _supplierEmailController.text.trim(),
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        mrp: mrp,
        stockQuantity: stockQuantity,
        minimumStockLevel: minStock,
        maximumStockLevel: maxStock,
        locationRack: _locationRackController.text.trim().isEmpty
            ? null
            : _locationRackController.text.trim(),
        isActive: _isActive,
      );

      // Use upsertInventory to create or update inventory
      final result = await _productService.upsertInventory(inventory);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _isLoading = false;
          if (result['errors'] != null) {
            // Map backend error keys to form field keys used here
            final Map<String, String> backendErrors = Map<String, String>.from(
              result['errors'],
            );
            final Map<String, String> uiErrors = {};

            backendErrors.forEach((k, v) {
              switch (k) {
                case 'costPrice':
                case 'cost_price':
                  uiErrors['cost_price'] = v;
                  break;
                case 'sellingPrice':
                case 'selling_price':
                  uiErrors['selling_price'] = v;
                  break;
                case 'mrp':
                  uiErrors['mrp'] = v;
                  break;
                case 'stockQuantity':
                case 'stock_quantity':
                  uiErrors['stock_quantity'] = v;
                  break;
                case 'minimumStockLevel':
                case 'minimum_stock_level':
                  uiErrors['minimum_stock'] = v;
                  break;
                case 'maximumStockLevel':
                case 'maximum_stock_level':
                  uiErrors['maximum_stock'] = v;
                  break;
                case 'supplierEmail':
                case 'supplier_email':
                  uiErrors['supplier_email'] = v;
                  break;
                case 'supplierContact':
                case 'supplier_contact':
                  uiErrors['supplier_contact'] = v;
                  break;
                case 'supplierName':
                case 'supplier_name':
                  uiErrors['supplier_name'] = v;
                  break;
                default:
                  // Fallback to using raw key
                  uiErrors[k] = v;
              }
            });

            _fieldErrors = uiErrors;
          }
        });

        if (result['error'] != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['error']),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 650,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.inventory, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEditing ? 'Edit Inventory' : 'Add Inventory',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Product: ${widget.productName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Supplier Information Section
                      _buildSectionHeader('Supplier Information'),
                      const SizedBox(height: 16),

                      // Supplier Name
                      TextFormField(
                        controller: _supplierNameController,
                        decoration: InputDecoration(
                          labelText: 'Supplier Name',
                          border: const OutlineInputBorder(),
                          errorText: _fieldErrors['supplier_name'],
                        ),
                        validator: (value) {
                          if (value != null && value.length > 100) {
                            return 'Supplier name must not exceed 100 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Supplier Contact and Email Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _supplierContactController,
                              decoration: InputDecoration(
                                labelText: 'Supplier Contact',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['supplier_contact'],
                              ),
                              validator: (value) {
                                if (value != null && value.length > 100) {
                                  return 'Contact must not exceed 100 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _supplierEmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Supplier Email',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['supplier_email'],
                              ),
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  if (!RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  ).hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                  if (value.length > 100) {
                                    return 'Email must not exceed 100 characters';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pricing Section
                      _buildSectionHeader('Pricing Information'),
                      const SizedBox(height: 16),

                      // Cost Price, Selling Price, MRP Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _costPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Cost Price *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['cost_price'],
                                prefixText: '₹ ',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Cost price is required';
                                }
                                final price = double.tryParse(value.trim());
                                if (price == null) {
                                  return 'Invalid price format';
                                }
                                if (price < 0) {
                                  return 'Price cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sellingPriceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Selling Price *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['selling_price'],
                                prefixText: '₹ ',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Selling price is required';
                                }
                                final price = double.tryParse(value.trim());
                                if (price == null) {
                                  return 'Invalid price format';
                                }
                                if (price < 0) {
                                  return 'Price cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _mrpController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'MRP',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['mrp'],
                                prefixText: '₹ ',
                              ),
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final price = double.tryParse(value.trim());
                                  if (price == null) {
                                    return 'Invalid price format';
                                  }
                                  if (price < 0) {
                                    return 'Price cannot be negative';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stock Information Section
                      _buildSectionHeader('Stock Information'),
                      const SizedBox(height: 16),

                      // Stock Quantity and Levels Row
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _stockQuantityController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Current Stock *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['stock_quantity'],
                                suffixText: 'units',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Stock quantity is required';
                                }
                                final stock = int.tryParse(value.trim());
                                if (stock == null) {
                                  return 'Invalid stock format';
                                }
                                if (stock < 0) {
                                  return 'Stock cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _minimumStockController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Minimum Stock *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['minimum_stock'],
                                suffixText: 'units',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Minimum stock is required';
                                }
                                final stock = int.tryParse(value.trim());
                                if (stock == null) {
                                  return 'Invalid stock format';
                                }
                                if (stock < 0) {
                                  return 'Stock cannot be negative';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _maximumStockController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: 'Maximum Stock *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['maximum_stock'],
                                suffixText: 'units',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Maximum stock is required';
                                }
                                final stock = int.tryParse(value.trim());
                                if (stock == null) {
                                  return 'Invalid stock format';
                                }
                                if (stock < 1) {
                                  return 'Maximum stock must be at least 1';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Location Rack
                      SizedBox(
                        width: 300,
                        child: TextFormField(
                          controller: _locationRackController,
                          decoration: const InputDecoration(
                            labelText: 'Location/Rack',
                            border: OutlineInputBorder(),
                            hintText: 'e.g., A1-B2, Rack 5',
                          ),
                          validator: (value) {
                            if (value != null && value.length > 50) {
                              return 'Location must not exceed 50 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Active Checkbox
                      CheckboxListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Inventory record is active'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value ?? true;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveInventory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditing
                              ? 'Update Inventory'
                              : 'Add Inventory',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}
