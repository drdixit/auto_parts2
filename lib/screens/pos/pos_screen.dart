import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_parts2/models/main_category.dart';
import 'package:auto_parts2/models/manufacturer.dart';
import 'package:auto_parts2/models/product.dart';
import 'package:auto_parts2/models/sub_category.dart';
import 'package:auto_parts2/models/vehicle_model.dart';
import 'package:auto_parts2/services/main_category_service.dart';
import 'package:auto_parts2/services/product_service.dart';
import 'package:auto_parts2/services/sub_category_service.dart';
import 'package:auto_parts2/services/customer_service.dart';
import 'package:auto_parts2/services/hold_service.dart';
import 'package:auto_parts2/models/customer.dart';
import 'package:auto_parts2/theme/app_colors.dart';
import 'package:auto_parts2/screens/pos/dummy_invoice_dialog.dart';
import 'package:auto_parts2/utils/bill_utils.dart';

// Intents for keyboard shortcuts
class ResetIntent extends Intent {
  const ResetIntent();
}

// customer selection UI is rendered inside the billing panel below (see build)
/// Minimal billing item used by POS in-memory state.
class BillingItem {
  final Product? product;
  int qty;
  BillingItem({this.product, this.qty = 1});

  double get lineTotal => (product?.sellingPrice ?? 0.0) * qty;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class ClearBillIntent extends Intent {
  const ClearBillIntent();
}

class HeldBill {
  final int id;
  final DateTime createdAt;
  final List<BillingItem> items;
  final int? customerId;
  final String? customerName;
  final String searchQuery;
  final int? selectedMainCategoryId;
  final Set<int> selectedSubCategoryIds;
  final Set<int> selectedVehicleIds;
  final Set<int> selectedVehicleManufacturerIds;
  final Set<int> selectedProductManufacturerIds;

  HeldBill({
    required this.id,
    required this.createdAt,
    required this.items,
    this.customerId,
    this.customerName,
    required this.searchQuery,
    required this.selectedMainCategoryId,
    required this.selectedSubCategoryIds,
    required this.selectedVehicleIds,
    required this.selectedVehicleManufacturerIds,
    required this.selectedProductManufacturerIds,
  });
}

class _PosScreenState extends State<PosScreen> {
  final ProductService _productService = ProductService();
  final MainCategoryService _mainCatService = MainCategoryService();
  final SubCategoryService _subCatService = SubCategoryService();
  final CustomerService _customerService = CustomerService();

  List<MainCategory> _mainCategories = [];
  List<SubCategory> _subCategories = [];
  // map subCategoryId -> mainCategoryId for fast lookup
  final Map<int, int> _subToMain = {};
  List<VehicleModel> _vehicles = [];
  List<SubCategory> _visibleSubCategories = [];
  List<VehicleModel> _visibleVehicles = [];
  List<Manufacturer> _manufacturers = [];
  List<Manufacturer> _productManufacturers = [];

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // productId -> set of compatible vehicle ids
  final Map<int, Set<int>> _productCompatibility = {};

  // Filters
  int? _selectedMainCategoryId;
  final Set<int> _selectedSubCategoryIds = {};
  final Set<int> _selectedVehicleIds = {};
  final Set<int> _selectedVehicleManufacturerIds = {};
  final Set<int> _selectedProductManufacturerIds = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Billing
  final List<BillingItem> _billing = [];
  // Temporary holds are kept in the singleton HoldService so they survive
  // navigation within the same app session. They are not persisted to DB.
  List<HeldBill> get _heldBills => HoldService.instance.holds.cast<HeldBill>();
  List<Customer> _customers = [];
  int? _selectedCustomerId;
  String? _customerDisplayName;
  // persisted holds: no local sequence id required
  // If non-null, we're editing/updating an existing held bill with this id.
  int? _editingHoldId;
  // Version notifier to help dialogs / UI listen for held-bill changes.
  final ValueNotifier<int> _holdsVersion = ValueNotifier<int>(0);

  // Cached DB-held bills (maps as returned by service)
  List<Map<String, dynamic>> _dbHeldBills = [];

  void _bumpHoldsVersion() => _holdsVersion.value += 1;

  // UI tokens
  Color get _accentColor => Theme.of(context).colorScheme.primary;
  final Color _chipSelectedColor = const Color(0xFFE8ECFF);
  final double _cardRadius = 12.0;
  final double _panelRadius = 14.0;

  // Hover state for product cards
  int? _hoveredProductId;
  // Root focus node (kept for stability; keyboard handled via Shortcuts/Actions)
  final FocusNode _rootFocusNode = FocusNode();
  // Hover state for product cards

  double get _billingTotal => _billing.fold(0.0, (s, b) => s + b.lineTotal);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
      _onSearchChanged(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _rootFocusNode.dispose();
    super.dispose();
  }

  // Raw key handling is done via Shortcuts/Actions; no local handler needed.

  // Raw keyboard handling replaced by Shortcuts/Actions (see build)

  Future<void> _loadInitialData() async {
    _mainCategories = await _mainCatService.getAllCategories();
    _subCategories = await _subCatService.getAllSubCategories();
    _vehicles = await _productService.getAllVehicleModels();
    _manufacturers = await _productService.getPartsManufacturers();
    _productManufacturers = List.from(_manufacturers);
    _allProducts = await _productService.getAllProducts();
    // load customers
    _customers = await _customerService.getAllCustomers();
    // preload compatibility for products to enable exact vehicle filtering
    for (final p in _allProducts) {
      if (p.id == null) continue;
      final comps = await _productService.getProductCompatibility(p.id!);
      _productCompatibility[p.id!] = comps
          .map((c) => c.vehicleModelId)
          .whereType<int>()
          .toSet();
    }
    setState(() {
      _visibleSubCategories = List.from(_subCategories);
      _visibleVehicles = List.from(_vehicles);
      _filteredProducts = List.from(_allProducts);
    });
    // load persisted holds from DB
    _dbHeldBills = await _customerService.getHeldBills();
    // build sub->main map
    for (final s in _subCategories) {
      if (s.id != null) _subToMain[s.id!] = s.mainCategoryId;
    }

    setState(() {
      _visibleSubCategories = List.from(_subCategories);
      _visibleVehicles = List.from(_vehicles);
      _filteredProducts = List.from(_allProducts);
    });
  }

  void _updateVisibleForMainCategory() {
    if (_selectedMainCategoryId == null) {
      _visibleSubCategories = List.from(_subCategories);
      _visibleVehicles = List.from(_vehicles);
    } else {
      _visibleSubCategories = _subCategories
          .where((s) => s.mainCategoryId == _selectedMainCategoryId)
          .toList();
      // Vehicles aren't linked to main categories in current schema; keep all
      _visibleVehicles = List.from(_vehicles);
    }
  }

  void _applyFilters() {
    _filteredProducts = _allProducts.where((p) {
      if (_selectedSubCategoryIds.isNotEmpty &&
          !_selectedSubCategoryIds.contains(p.subCategoryId)) {
        return false;
      }
      if (_selectedMainCategoryId != null) {
        final mainForProduct = _subToMain[p.subCategoryId];
        if (mainForProduct != _selectedMainCategoryId) {
          return false;
        }
      }
      // Apply vehicle compatibility using preloaded map.
      if (_selectedVehicleIds.isNotEmpty && !p.isUniversal) {
        final compat = p.id != null
            ? _productCompatibility[p.id!] ?? <int>{}
            : <int>{};
        // if no compat entries, be conservative and allow the product
        if (compat.isNotEmpty &&
            compat.intersection(_selectedVehicleIds).isEmpty) {
          return false;
        }
      }
      if (_selectedProductManufacturerIds.isNotEmpty &&
          !_selectedProductManufacturerIds.contains(p.manufacturerId)) {
        return false;
      }
      if (_searchQuery.isNotEmpty && !_fuzzyMatch(p.name, _searchQuery)) {
        return false;
      }
      return true;
    }).toList();
    setState(() {});
  }

  bool _fuzzyMatch(String? text, String q) {
    if (text == null) {
      return false;
    }
    return text.toLowerCase().contains(q.toLowerCase());
  }

  void _onSearchChanged(String q) {
    _searchQuery = q;
    _applyFilters();
  }

  void _selectMainCategory(int? id) {
    setState(() {
      _selectedMainCategoryId = id;
      _selectedSubCategoryIds.clear();
      _selectedVehicleIds.clear();
      _updateVisibleForMainCategory();
      _applyFilters();
    });
  }

  void _toggleSubCategory(int id) {
    setState(() {
      if (_selectedSubCategoryIds.contains(id)) {
        _selectedSubCategoryIds.remove(id);
      } else {
        _selectedSubCategoryIds.add(id);
      }
      _applyFilters();
    });
  }

  void _toggleVehicle(int id) {
    setState(() {
      if (_selectedVehicleIds.contains(id)) {
        _selectedVehicleIds.remove(id);
      } else {
        _selectedVehicleIds.add(id);
      }
      _applyFilters();
    });
  }

  void _resetAllFilters() {
    setState(() {
      _selectedMainCategoryId = null;
      _selectedSubCategoryIds.clear();
      _selectedVehicleIds.clear();
      _selectedProductManufacturerIds.clear();
      _searchController.clear();
      _applyFilters();
    });
  }

  void _addToBilling(Product p) {
    setState(() {
      final existing = _billing.firstWhere(
        (b) => b.product!.id == p.id,
        orElse: () => BillingItem(product: p, qty: 0),
      );
      if (existing.qty == 0) {
        _billing.add(BillingItem(product: p));
      } else {
        existing.qty += 1;
      }
    });
  }

  void _removeFromBilling(Product p) {
    setState(() {
      final existing = _billing.firstWhere(
        (b) => b.product!.id == p.id,
        orElse: () => BillingItem(product: p, qty: 0),
      );
      if (existing.qty <= 1) {
        _billing.removeWhere((b) => b.product!.id == p.id);
      } else {
        existing.qty -= 1;
      }
    });
  }

  void _deleteFromBilling(Product p) {
    setState(() {
      _billing.removeWhere((b) => b.product!.id == p.id);
    });
  }

  void _holdCurrentBill() {
    // If we're editing an existing held bill, update it in-place; otherwise create a new hold.
    final itemsCopy = List<BillingItem>.from(
      _billing.map((b) => BillingItem(product: b.product, qty: b.qty)),
    );
    if (_editingHoldId != null) {
      final idx = _heldBills.indexWhere((h) => h.id == _editingHoldId);
      if (idx != -1) {
        final existing = _heldBills[idx];
        final updated = HeldBill(
          id: existing.id,
          createdAt: existing.createdAt,
          items: itemsCopy,
          customerId: _selectedCustomerId,
          customerName: _customers
              .firstWhere(
                (c) => c.id == _selectedCustomerId,
                orElse: () => Customer(name: '', address: '', mobile: ''),
              )
              .name,
          searchQuery: _searchQuery,
          selectedMainCategoryId: _selectedMainCategoryId,
          selectedSubCategoryIds: Set.from(_selectedSubCategoryIds),
          selectedVehicleIds: Set.from(_selectedVehicleIds),
          selectedVehicleManufacturerIds: Set.from(
            _selectedVehicleManufacturerIds,
          ),
          selectedProductManufacturerIds: Set.from(
            _selectedProductManufacturerIds,
          ),
        );
        setState(() {
          _heldBills[idx] = updated;
          _billing.clear();
          _editingHoldId = null; // finished editing
          _bumpHoldsVersion();
        });
        return;
      }
      // If the previously editing hold disappeared (deleted), fall through and create a new one.
      _editingHoldId = null;
    }

    // Ensure a customer is selected - DB requires customer_id NOT NULL.
    if (_selectedCustomerId == null) {
      // Prompt the user to select or create a customer
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No customer selected'),
          content: const Text(
            'Please select an existing customer or create a new customer before holding a bill.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Create a simple new-customer dialog (same flow as the New button)
                final nameCtrl = TextEditingController();
                final addrCtrl = TextEditingController();
                final mobileCtrl = TextEditingController();
                final openingBalanceCtrl = TextEditingController(text: '0.0');
                final created = await showDialog<Customer?>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Create customer'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        TextField(
                          controller: addrCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                        ),
                        TextField(
                          controller: mobileCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: openingBalanceCtrl,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Starting balance (optional)',
                            hintText: '0.0',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final c = Customer(
                            name: nameCtrl.text.trim(),
                            address: addrCtrl.text.trim(),
                            mobile: mobileCtrl.text.trim(),
                          );
                          // parse opening balance
                          final ob =
                              double.tryParse(openingBalanceCtrl.text) ?? 0.0;
                          c.openingBalance = ob;
                          c.balance = ob;
                          // capture navigator to avoid using BuildContext after await
                          final nav = Navigator.of(context);
                          final id = await _customerService.createCustomer(c);
                          c.id = id;
                          nav.pop(c);
                        },
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );
                if (created != null) {
                  _customers = await _customerService.getAllCustomers();
                  if (!mounted) return;
                  setState(() => _selectedCustomerId = created.id);
                  // After creation, retry holding the bill automatically
                  _holdCurrentBill();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
      return;
    }

    // Create an in-memory (temporary) hold that lives for this app session.
    // Use a negative id to avoid colliding with DB ids (DB ids are positive).
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final hb = HeldBill(
      id: tempId,
      createdAt: DateTime.now(),
      items: itemsCopy,
      customerId: _selectedCustomerId,
      customerName: _customers
          .firstWhere(
            (c) => c.id == _selectedCustomerId,
            orElse: () => Customer(name: '', address: '', mobile: ''),
          )
          .name,
      searchQuery: _searchQuery,
      selectedMainCategoryId: _selectedMainCategoryId,
      selectedSubCategoryIds: Set.from(_selectedSubCategoryIds),
      selectedVehicleIds: Set.from(_selectedVehicleIds),
      selectedVehicleManufacturerIds: Set.from(_selectedVehicleManufacturerIds),
      selectedProductManufacturerIds: Set.from(_selectedProductManufacturerIds),
    );

    setState(() {
      _heldBills.add(hb);
      _billing.clear();
      _editingHoldId = null;
      _bumpHoldsVersion();
    });
  }

  void _openHeldBills() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Held Bills'),
        content: SizedBox(
          width: 560,
          child: StatefulBuilder(
            builder: (context, dialogSetState) {
              final hasDb = _dbHeldBills.isNotEmpty;
              final hasTemp = _heldBills.isNotEmpty;
              if (!hasDb && !hasTemp) {
                return const Center(child: Text('No held bills'));
              }

              return ListView(
                shrinkWrap: true,
                children: [
                  if (hasTemp) ...[
                    const ListTile(title: Text('Temporary holds')),
                    ..._heldBills.map((hb) {
                      final items = hb.items;
                      final totalQty = items.fold<int>(
                        0,
                        (s, it) => s + it.qty,
                      );
                      return ListTile(
                        title: Text(
                          (hb.customerName?.isNotEmpty ?? false)
                              ? 'Temp ${hb.id} (${hb.customerName}) - ${items.length} - $totalQty'
                              : 'Temp ${hb.id} - ${items.length} - $totalQty',
                        ),
                        subtitle: Text('${hb.createdAt}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                _loadHeldBill(hb);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Load'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete temp hold?'),
                                    content: const Text(
                                      'Remove this temporary held bill?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  dialogSetState(() async {
                                    _heldBills.removeWhere(
                                      (h) => h.id == hb.id,
                                    );
                                    _bumpHoldsVersion();
                                    if (!mounted) return;
                                    setState(() {});
                                  });
                                }
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],

                  if (hasDb) ...[
                    const Divider(),
                    const ListTile(title: Text('Persisted holds')),
                    ..._dbHeldBills.map((hb) {
                      final items = (hb['items'] as List)
                          .cast<Map<String, dynamic>>();
                      final totalQty = items.fold<int>(
                        0,
                        (s, it) => s + (it['qty'] as int? ?? 0),
                      );
                      final customer = _customers.firstWhere(
                        (c) => c.id == (hb['customer_id'] as int?),
                        orElse: () =>
                            Customer(name: '', address: '', mobile: ''),
                      );
                      return ListTile(
                        title: Text(
                          (customer.name.isNotEmpty)
                              ? 'Hold ${formatBillCode(hb['id'], hb['created_at'] as String?)} (${customer.name}) - ${items.length} - $totalQty'
                              : 'Hold ${formatBillCode(hb['id'], hb['created_at'] as String?)} - ${items.length} - $totalQty',
                        ),
                        subtitle: Text('${hb['created_at']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                // load in parent state and close dialog
                                _loadDbHeldBill(hb);
                                Navigator.of(context).pop();
                              },
                              child: const Text('Load'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete hold?'),
                                    content: const Text(
                                      'Remove this held bill?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _customerService.deleteHeldBill(
                                    hb['id'] as int,
                                  );
                                  dialogSetState(() async {
                                    _dbHeldBills = await _customerService
                                        .getHeldBills();
                                    _bumpHoldsVersion();
                                    if (!mounted) return;
                                    setState(() {});
                                  });
                                }
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: _heldBills.isEmpty
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear all holds?'),
                        content: const Text(
                          'This will remove all held bills. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      if (!mounted) return;
                      setState(() {
                        _heldBills.clear();
                        _editingHoldId = null;
                        _bumpHoldsVersion();
                      });
                      final n = nav;
                      final m = messenger;
                      n.pop();
                      m.showSnackBar(
                        const SnackBar(content: Text('All held bills cleared')),
                      );
                    }
                  },
            child: Text(
              'Clear all holds',
              style: TextStyle(
                color: _heldBills.isEmpty
                    ? AppColors.surfaceMuted
                    : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadHeldBill(HeldBill hb) {
    setState(() {
      _billing.clear();
      _billing.addAll(
        hb.items.map((i) => BillingItem(product: i.product, qty: i.qty)),
      );
      _searchController.text = hb.searchQuery;
      _selectedMainCategoryId = hb.selectedMainCategoryId;
      _selectedSubCategoryIds.clear();
      _selectedSubCategoryIds.addAll(hb.selectedSubCategoryIds);
      _selectedVehicleIds.clear();
      _selectedVehicleIds.addAll(hb.selectedVehicleIds);
      _selectedProductManufacturerIds.clear();
      _selectedProductManufacturerIds.addAll(hb.selectedProductManufacturerIds);
      // restore selected customer for this held bill (if any)
      if (hb.customerId != null && hb.customerId != 0) {
        _selectedCustomerId = hb.customerId;
        // also set the display name (in case the customer list hasn't refreshed)
        _customerDisplayName = hb.customerName;
      } else {
        _selectedCustomerId = null;
        _customerDisplayName = hb.customerName;
      }
      _applyFilters();
      // mark that we're editing this held bill so a subsequent Hold action updates it
      _editingHoldId = hb.id;
    });
  }

  // Load a DB-held bill (map) into in-memory billing state
  void _loadDbHeldBill(Map<String, dynamic> hb) {
    final items = (hb['items'] as List).cast<Map<String, dynamic>>();
    setState(() {
      _billing.clear();
      for (final it in items) {
        final pid = it['product_id'] as int?;
        final qty = it['qty'] as int? ?? 1;
        final product = _allProducts.firstWhere(
          (p) => p.id == pid,
          orElse: () => Product(
            id: null,
            name: 'Unknown',
            subCategoryId: 0,
            manufacturerId: 0,
            sellingPrice: 0.0,
          ),
        );
        _billing.add(BillingItem(product: product, qty: qty));
      }
      _editingHoldId = hb['id'] as int?;
      // restore selected customer if present
      final cid = hb['customer_id'] as int?;
      if (cid != null && cid != 0) {
        _selectedCustomerId = cid;
        _customerDisplayName = hb['customer_name'] as String?;
      } else {
        _selectedCustomerId = null;
        _customerDisplayName = hb['customer_name'] as String?;
      }
      _searchController.text = hb['searchQuery'] ?? '';
    });
  }

  // ...existing code...

  void _clearBill() {
    setState(() => _billing.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const ResetIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX):
            const ClearBillIntent(),
      },
      child: Actions(
        actions: {
          ResetIntent: CallbackAction<ResetIntent>(
            onInvoke: (_) {
              _resetAllFilters();
              return null;
            },
          ),
          ClearBillIntent: CallbackAction<ClearBillIntent>(
            onInvoke: (_) {
              _clearBill();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: AppColors.surfaceLight,
            body: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: LayoutBuilder(
                      builder: (context, outer) {
                        final outerWidth = outer.maxWidth;
                        final leftWidth = outerWidth < 1000
                            ? 320.0
                            : (outerWidth * 0.22).clamp(320.0, 420.0);
                        final rightWidth = outerWidth < 1000
                            ? 360.0
                            : (outerWidth * 0.20).clamp(360.0, 520.0);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: leftWidth,
                              child: Container(
                                decoration: _panelDecoration,
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.tune,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Filters',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          onPressed: _resetAllFilters,
                                          icon: const Icon(Icons.refresh),
                                          tooltip: 'Reset filters',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Main Category',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                FilterChip(
                                                  label: const Text('All'),
                                                  selected:
                                                      _selectedMainCategoryId ==
                                                      null,
                                                  onSelected: (_) =>
                                                      _selectMainCategory(null),
                                                  backgroundColor:
                                                      AppColors.transparent,
                                                  selectedColor:
                                                      _chipSelectedColor,
                                                  checkmarkColor: _accentColor,
                                                  labelStyle: TextStyle(
                                                    color:
                                                        _selectedMainCategoryId ==
                                                            null
                                                        ? _accentColor
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: BorderSide(
                                                      color:
                                                          _selectedMainCategoryId ==
                                                              null
                                                          ? _accentColor
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .round(),
                                                                )
                                                          : AppColors
                                                                .surfaceMuted
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .round(),
                                                                ),
                                                    ),
                                                  ),
                                                  showCheckmark: true,
                                                ),
                                                ..._mainCategories.map((c) {
                                                  final sel =
                                                      _selectedMainCategoryId ==
                                                      c.id;
                                                  return FilterChip(
                                                    label: Text(c.name),
                                                    selected: sel,
                                                    onSelected: (_) =>
                                                        _selectMainCategory(
                                                          c.id,
                                                        ),
                                                    backgroundColor:
                                                        AppColors.transparent,
                                                    selectedColor:
                                                        _chipSelectedColor,
                                                    checkmarkColor:
                                                        _accentColor,
                                                    labelStyle: TextStyle(
                                                      color: sel
                                                          ? _accentColor
                                                          : AppColors
                                                                .textSecondary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      side: BorderSide(
                                                        color: sel
                                                            ? _accentColor
                                                                  .withAlpha(
                                                                    (0.18 * 255)
                                                                        .round(),
                                                                  )
                                                            : AppColors
                                                                  .surfaceMuted
                                                                  .withAlpha(
                                                                    (0.12 * 255)
                                                                        .round(),
                                                                  ),
                                                      ),
                                                    ),
                                                    showCheckmark: true,
                                                  );
                                                }),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Divider(),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Sub Categories',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: _visibleSubCategories.map((
                                                s,
                                              ) {
                                                final sel =
                                                    _selectedSubCategoryIds
                                                        .contains(s.id);
                                                return FilterChip(
                                                  label: Text(s.name),
                                                  selected: sel,
                                                  onSelected: (_) =>
                                                      _toggleSubCategory(s.id!),
                                                  backgroundColor:
                                                      AppColors.transparent,
                                                  selectedColor:
                                                      _chipSelectedColor,
                                                  checkmarkColor: _accentColor,
                                                  labelStyle: TextStyle(
                                                    color: sel
                                                        ? _accentColor
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: BorderSide(
                                                      color: sel
                                                          ? _accentColor
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .round(),
                                                                )
                                                          : AppColors
                                                                .surfaceMuted
                                                                .withAlpha(
                                                                  (0.12 * 255)
                                                                      .round(),
                                                                ),
                                                    ),
                                                  ),
                                                  showCheckmark: true,
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Vehicles',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: _visibleVehicles.map((
                                                v,
                                              ) {
                                                final sel = _selectedVehicleIds
                                                    .contains(v.id);
                                                return FilterChip(
                                                  label: Text(v.displayName),
                                                  selected: sel,
                                                  onSelected: (_) =>
                                                      _toggleVehicle(v.id!),
                                                  backgroundColor:
                                                      AppColors.transparent,
                                                  selectedColor:
                                                      _chipSelectedColor,
                                                  checkmarkColor: _accentColor,
                                                  labelStyle: TextStyle(
                                                    color: sel
                                                        ? _accentColor
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: BorderSide(
                                                      color: sel
                                                          ? _accentColor
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .round(),
                                                                )
                                                          : AppColors
                                                                .surfaceMuted
                                                                .withAlpha(
                                                                  (0.12 * 255)
                                                                      .round(),
                                                                ),
                                                    ),
                                                  ),
                                                  showCheckmark: true,
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Manufacturers',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: _productManufacturers.map((
                                                m,
                                              ) {
                                                final sel =
                                                    _selectedProductManufacturerIds
                                                        .contains(m.id);
                                                return FilterChip(
                                                  label: Text(m.name),
                                                  selected: sel,
                                                  onSelected: (_) => setState(() {
                                                    if (_selectedProductManufacturerIds
                                                        .contains(m.id)) {
                                                      _selectedProductManufacturerIds
                                                          .remove(m.id);
                                                    } else {
                                                      _selectedProductManufacturerIds
                                                          .add(m.id!);
                                                    }
                                                    _applyFilters();
                                                  }),
                                                  backgroundColor:
                                                      AppColors.transparent,
                                                  selectedColor:
                                                      _chipSelectedColor,
                                                  checkmarkColor: _accentColor,
                                                  labelStyle: TextStyle(
                                                    color: sel
                                                        ? _accentColor
                                                        : AppColors
                                                              .textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    side: BorderSide(
                                                      color: sel
                                                          ? _accentColor
                                                                .withAlpha(
                                                                  (0.18 * 255)
                                                                      .round(),
                                                                )
                                                          : AppColors
                                                                .surfaceMuted
                                                                .withAlpha(
                                                                  (0.12 * 255)
                                                                      .round(),
                                                                ),
                                                    ),
                                                  ),
                                                  showCheckmark: true,
                                                );
                                              }).toList(),
                                            ),
                                            const SizedBox(height: 12),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Center: Product grid
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Text(
                                        '${_filteredProducts.length} products',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: _panelDecoration,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final width = constraints.maxWidth;
                                          // Responsive columns: compute how many columns fit by a minimum card width,
                                          // but limit to 2 or 3 columns only (desktop-focused). This ensures 3 columns
                                          // on wide displays (e.g. a maximized 1080p window) while using 2 columns on narrow panes.
                                          final spacing = 8.0;
                                          const int minCols = 2;
                                          const int maxCols = 3;
                                          // Minimum practical card width for our layout. Reduced so 3 columns fit on common 1080p center widths.
                                          const double minCardWidth = 220.0;
                                          final computedCols =
                                              ((width + spacing) /
                                                      (minCardWidth + spacing))
                                                  .floor();
                                          final int crossAxisCount =
                                              computedCols.clamp(
                                                minCols,
                                                maxCols,
                                              );
                                          // recalc card width and derive a childAspectRatio that keeps height sensible
                                          final cardWidth =
                                              (width -
                                                  (crossAxisCount - 1) *
                                                      spacing) /
                                              crossAxisCount;
                                          // Make image smaller than full card width so the
                                          // remaining text/buttons fit without overflow.
                                          final imageHeight =
                                              cardWidth *
                                              0.50; // 50% of card width
                                          // card height = image area + space for title, price and buttons
                                          // add a slightly larger safety margin to avoid pixel rounding overflow
                                          final desiredCardHeight =
                                              imageHeight + 80.0;
                                          final childAspectRatio =
                                              cardWidth / desiredCardHeight;
                                          // small bottom padding for visual balance
                                          return _filteredProducts.isEmpty
                                              ? const Center(
                                                  child: Text('No products'),
                                                )
                                              : GridView.builder(
                                                  padding: EdgeInsets.only(
                                                    bottom: 12,
                                                    top: spacing,
                                                  ),
                                                  physics:
                                                      const AlwaysScrollableScrollPhysics(),
                                                  shrinkWrap: false,
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount:
                                                            crossAxisCount,
                                                        crossAxisSpacing:
                                                            spacing,
                                                        mainAxisSpacing:
                                                            spacing,
                                                        childAspectRatio:
                                                            childAspectRatio
                                                                .clamp(
                                                                  0.6,
                                                                  1.6,
                                                                ),
                                                      ),
                                                  itemCount:
                                                      _filteredProducts.length,
                                                  itemBuilder: (context, i) {
                                                    final p =
                                                        _filteredProducts[i];
                                                    final price =
                                                        p.sellingPrice ?? 0.0;
                                                    final inCart = _billing
                                                        .where(
                                                          (b) =>
                                                              b.product!.id ==
                                                              p.id,
                                                        )
                                                        .fold<int>(
                                                          0,
                                                          (s, b) => s + b.qty,
                                                        );
                                                    return MouseRegion(
                                                      onEnter: (_) => setState(
                                                        () =>
                                                            _hoveredProductId =
                                                                p.id,
                                                      ),
                                                      onExit: (_) => setState(
                                                        () =>
                                                            _hoveredProductId =
                                                                null,
                                                      ),
                                                      child: AnimatedPhysicalModel(
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 180,
                                                            ),
                                                        curve: Curves.easeOut,
                                                        elevation:
                                                            _hoveredProductId ==
                                                                p.id
                                                            ? 8
                                                            : 2,
                                                        shape:
                                                            BoxShape.rectangle,
                                                        shadowColor: AppColors
                                                            .textSecondary
                                                            .withAlpha(
                                                              (0.6 * 255)
                                                                  .round(),
                                                            ),
                                                        color:
                                                            AppColors.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              _cardRadius,
                                                            ),
                                                        child: Transform.scale(
                                                          scale:
                                                              _hoveredProductId ==
                                                                  p.id
                                                              ? 1.02
                                                              : 1.0,
                                                          child: Material(
                                                            color: AppColors
                                                                .surface,
                                                            elevation: 0,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  _cardRadius,
                                                                ),
                                                            child: GestureDetector(
                                                              behavior:
                                                                  HitTestBehavior
                                                                      .translucent,
                                                              onSecondaryTap: () =>
                                                                  _removeFromBilling(
                                                                    p,
                                                                  ),
                                                              child: InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      _cardRadius,
                                                                    ),
                                                                onTap: () =>
                                                                    _addToBilling(
                                                                      p,
                                                                    ),
                                                                child: Padding(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8.0,
                                                                        vertical:
                                                                            4.0,
                                                                      ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      SizedBox(
                                                                        height:
                                                                            imageHeight,
                                                                        child: ClipRRect(
                                                                          borderRadius: BorderRadius.circular(
                                                                            _cardRadius -
                                                                                4,
                                                                          ),
                                                                          child:
                                                                              p.primaryImagePath !=
                                                                                      null &&
                                                                                  p.primaryImagePath!.isNotEmpty
                                                                              ? Container(
                                                                                  color: AppColors.surfaceMuted,
                                                                                  alignment: Alignment.center,
                                                                                  child: Image.file(
                                                                                    File(
                                                                                      p.primaryImagePath!,
                                                                                    ),
                                                                                    fit: BoxFit.contain,
                                                                                    width:
                                                                                        cardWidth *
                                                                                        0.9,
                                                                                    height:
                                                                                        imageHeight *
                                                                                        0.9,
                                                                                    errorBuilder:
                                                                                        (
                                                                                          _,
                                                                                          __,
                                                                                          ___,
                                                                                        ) => Container(
                                                                                          color: AppColors.surfaceMuted,
                                                                                          alignment: Alignment.center,
                                                                                          child: const Text(
                                                                                            'No image',
                                                                                          ),
                                                                                        ),
                                                                                  ),
                                                                                )
                                                                              : Container(
                                                                                  color: AppColors.surfaceMuted,
                                                                                  alignment: Alignment.center,
                                                                                  child: const Text(
                                                                                    'No image',
                                                                                  ),
                                                                                ),
                                                                        ),
                                                                      ),
                                                                      // tighten vertical spacing and allow title two lines
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text(
                                                                        p.name,
                                                                        maxLines:
                                                                            2,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              13.0,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            2,
                                                                      ),
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Text(
                                                                            '₹${price.toStringAsFixed(2)}',
                                                                            style: TextStyle(
                                                                              color: AppColors.textPrimary,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                          Row(
                                                                            children: [
                                                                              IconButton(
                                                                                iconSize: 18,
                                                                                padding: const EdgeInsets.all(
                                                                                  4,
                                                                                ),
                                                                                constraints: const BoxConstraints(),
                                                                                icon: const Icon(
                                                                                  Icons.remove_circle_outline,
                                                                                ),
                                                                                onPressed: () => _removeFromBilling(
                                                                                  p,
                                                                                ),
                                                                                splashRadius: 18,
                                                                              ),
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  horizontal: 8,
                                                                                  vertical: 4,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  color:
                                                                                      inCart >
                                                                                          0
                                                                                      ? _chipSelectedColor
                                                                                      : AppColors.transparent,
                                                                                  borderRadius: BorderRadius.circular(
                                                                                    6,
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  '$inCart',
                                                                                  style: const TextStyle(
                                                                                    fontWeight: FontWeight.w600,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              IconButton(
                                                                                iconSize: 18,
                                                                                padding: const EdgeInsets.all(
                                                                                  4,
                                                                                ),
                                                                                constraints: const BoxConstraints(),
                                                                                icon: const Icon(
                                                                                  Icons.add_circle_outline,
                                                                                ),
                                                                                onPressed: () => _addToBilling(
                                                                                  p,
                                                                                ),
                                                                                splashRadius: 18,
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            SizedBox(
                              width: rightWidth,
                              child: Container(
                                decoration: _panelDecoration,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Billing',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: _accentColor,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_billing.length} items',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Customer selection: required before creating an invoice
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Autocomplete<Customer>(
                                            optionsBuilder: (textEditingValue) {
                                              if (textEditingValue
                                                  .text
                                                  .isEmpty) {
                                                return _customers;
                                              }
                                              final q = textEditingValue.text
                                                  .toLowerCase();
                                              return _customers.where((c) {
                                                return (c.name
                                                        .toLowerCase()
                                                        .contains(q) ||
                                                    (c.mobile ?? '')
                                                        .toLowerCase()
                                                        .contains(q) ||
                                                    (c.address ?? '')
                                                        .toLowerCase()
                                                        .contains(q));
                                              }).toList();
                                            },
                                            displayStringForOption: (c) =>
                                                '${c.name} ${c.mobile ?? ''}',
                                            fieldViewBuilder:
                                                (
                                                  context,
                                                  controller,
                                                  focusNode,
                                                  onFieldSubmitted,
                                                ) {
                                                  // Avoid clobbering user input while the field is focused.
                                                  // Resolve selected customer name if possible, otherwise fall back
                                                  // to the preserved display name from a held bill.
                                                  String displayText =
                                                      _customerDisplayName ??
                                                      '';
                                                  if (_selectedCustomerId !=
                                                      null) {
                                                    final resolved = _customers
                                                        .firstWhere(
                                                          (c) =>
                                                              c.id ==
                                                              _selectedCustomerId,
                                                          orElse: () =>
                                                              Customer(
                                                                name: '',
                                                                address: '',
                                                                mobile: '',
                                                              ),
                                                        );
                                                    if (resolved
                                                        .name
                                                        .isNotEmpty) {
                                                      displayText =
                                                          resolved.name;
                                                      // also keep the preserved display name in sync
                                                      _customerDisplayName =
                                                          resolved.name;
                                                    }
                                                  }

                                                  // Only update the controller when the field is not focused
                                                  // (so typing by the user isn't overwritten) and when the text differs.
                                                  if (!focusNode.hasFocus &&
                                                      controller.text !=
                                                          displayText) {
                                                    controller.text =
                                                        displayText;
                                                  }

                                                  return TextField(
                                                    controller: controller,
                                                    focusNode: focusNode,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Customer',
                                                          hintText:
                                                              'Search customers by name, mobile or address',
                                                        ),
                                                    onSubmitted: (_) =>
                                                        onFieldSubmitted(),
                                                  );
                                                },
                                            onSelected: (c) {
                                              setState(() {
                                                _selectedCustomerId = c.id;
                                                _customerDisplayName = c.name;
                                              });
                                            },
                                            optionsViewBuilder:
                                                (context, onSelected, options) {
                                                  return Material(
                                                    elevation: 4,
                                                    child: ListView(
                                                      padding: EdgeInsets.zero,
                                                      shrinkWrap: true,
                                                      children: options.map((
                                                        c,
                                                      ) {
                                                        return ListTile(
                                                          title: Text(c.name),
                                                          subtitle: Text(
                                                            '${c.mobile ?? ''} ${c.address ?? ''}',
                                                          ),
                                                          onTap: () =>
                                                              onSelected(c),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () async {
                                            // show create customer dialog
                                            final nameCtrl =
                                                TextEditingController();
                                            final addrCtrl =
                                                TextEditingController();
                                            final mobileCtrl =
                                                TextEditingController();
                                            final created = await showDialog<Customer?>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Create Customer',
                                                ),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    TextField(
                                                      controller: nameCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Name',
                                                          ),
                                                    ),
                                                    TextField(
                                                      controller: addrCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText:
                                                                'Address',
                                                          ),
                                                    ),
                                                    TextField(
                                                      controller: mobileCtrl,
                                                      decoration:
                                                          const InputDecoration(
                                                            labelText: 'Mobile',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(null),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      if (nameCtrl.text
                                                          .trim()
                                                          .isEmpty) {
                                                        return;
                                                      }
                                                      final c = Customer(
                                                        name: nameCtrl.text
                                                            .trim(),
                                                        address: addrCtrl.text
                                                            .trim(),
                                                        mobile: mobileCtrl.text
                                                            .trim(),
                                                      );
                                                      final navigator =
                                                          Navigator.of(context);
                                                      final id =
                                                          await _customerService
                                                              .createCustomer(
                                                                c,
                                                              );
                                                      c.id = id;
                                                      navigator.pop(c);
                                                    },
                                                    child: const Text('Create'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (created != null) {
                                              _customers =
                                                  await _customerService
                                                      .getAllCustomers();
                                              if (!mounted) return;
                                              setState(
                                                () => _selectedCustomerId =
                                                    created.id,
                                              );
                                            }
                                          },
                                          child: const Text('New'),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: _billing.isEmpty
                                          ? const Center(
                                              child: Text('No items'),
                                            )
                                          : ListView.builder(
                                              itemCount: _billing.length,
                                              itemBuilder: (context, i) {
                                                final b = _billing[i];
                                                return Card(
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 6,
                                                      ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 8,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        // Delete at front
                                                        InkWell(
                                                          onTap: () =>
                                                              _deleteFromBilling(
                                                                b.product!,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .red[50],
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                            child: Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 18,
                                                              color: Colors
                                                                  .red[700],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                b.product!.name,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                '₹${(b.product!.sellingPrice ?? 0).toStringAsFixed(2)} each',
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.bodySmall,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        // Quantity controls
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .surfaceLight,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .surfaceMuted
                                                                  .withAlpha(
                                                                    (0.8 * 255)
                                                                        .round(),
                                                                  ),
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                onTap: () =>
                                                                    _removeFromBilling(
                                                                      b.product!,
                                                                    ),
                                                                child: const Padding(
                                                                  padding:
                                                                      EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  child: Icon(
                                                                    Icons
                                                                        .remove,
                                                                    size: 18,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              Text(
                                                                '${b.qty}',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              InkWell(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      6,
                                                                    ),
                                                                onTap: () =>
                                                                    _addToBilling(
                                                                      b.product!,
                                                                    ),
                                                                child: const Padding(
                                                                  padding:
                                                                      EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  child: Icon(
                                                                    Icons.add,
                                                                    size: 18,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        // Line total
                                                        Text(
                                                          '₹${(b.lineTotal).toStringAsFixed(2)}',
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          '₹${_billingTotal.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _accentColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Quick access held bills: show up to 5 recent holds as buttons
                                    const SizedBox(height: 8),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _holdsVersion,
                                      builder: (context, holdsVersion, _) {
                                        final displayHolds = _heldBills.reversed
                                            .take(5)
                                            .toList();
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            // Hold current bill button
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                elevation: 0,
                                                backgroundColor: AppColors
                                                    .surfaceMuted
                                                    .withAlpha(
                                                      (0.8 * 255).round(),
                                                    ),
                                                foregroundColor:
                                                    AppColors.textPrimary,
                                              ),
                                              onPressed: _billing.isEmpty
                                                  ? null
                                                  : _holdCurrentBill,
                                              icon: const Icon(
                                                Icons.pause_circle,
                                              ),
                                              label: const Text('Hold'),
                                            ),
                                            // Quick-held buttons (recent first) - fixed width, with delete
                                            ...displayHolds.map((hb) {
                                              final totalQty = hb.items
                                                  .fold<int>(
                                                    0,
                                                    (s, it) => s + it.qty,
                                                  );
                                              return SizedBox(
                                                width: 92,
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _loadHeldBill(hb),
                                                  style: OutlinedButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            // show customer name (if any) + item-count on the quick-hold button
                                                            Text(
                                                              hb.customerName !=
                                                                          null &&
                                                                      hb
                                                                          .customerName!
                                                                          .isNotEmpty
                                                                  ? '${hb.customerName}\n${hb.items.length}-$totalQty'
                                                                  : '${hb.items.length}-$totalQty',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: AppColors
                                                                    .textPrimary,
                                                              ),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      // per-button delete
                                                      InkWell(
                                                        onTap: () async {
                                                          final messenger =
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              );
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (context) => AlertDialog(
                                                              title: const Text(
                                                                'Delete hold?',
                                                              ),
                                                              content: const Text(
                                                                'Remove this held bill?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.of(
                                                                        context,
                                                                      ).pop(
                                                                        true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Delete',
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          if (confirm == true) {
                                                            if (!mounted) {
                                                              return;
                                                            }
                                                            setState(() {
                                                              _heldBills.remove(
                                                                hb,
                                                              );
                                                              if (_editingHoldId ==
                                                                  hb.id) {
                                                                _editingHoldId =
                                                                    null;
                                                              }
                                                              _bumpHoldsVersion();
                                                            });
                                                            messenger.showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                  'Held bill removed',
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                left: 6,
                                                              ),
                                                          child: Icon(
                                                            Icons.close,
                                                            size: 16,
                                                            color: AppColors
                                                                .error
                                                                .withAlpha(
                                                                  (0.8 * 255)
                                                                      .round(),
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),
                                            // If there are more than 5 holds, show a 'More' button to open full list
                                            if (_heldBills.length > 5)
                                              OutlinedButton(
                                                onPressed: _openHeldBills,
                                                child: Text(
                                                  'More (${_heldBills.length})',
                                                ),
                                              ),
                                            // Clear all holds button
                                            OutlinedButton.icon(
                                              onPressed: _heldBills.isEmpty
                                                  ? null
                                                  : () async {
                                                      final messenger =
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          );
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              'Clear all holds?',
                                                            ),
                                                            content: const Text(
                                                              'This will remove all held bills. This action cannot be undone.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                                child: const Text(
                                                                  'Clear',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                      if (confirm == true) {
                                                        if (!mounted) return;
                                                        setState(() {
                                                          _heldBills.clear();
                                                          _editingHoldId = null;
                                                          _bumpHoldsVersion();
                                                        });
                                                        messenger.showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'All held bills cleared',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                              icon: const Icon(Icons.clear_all),
                                              label: const Text('Clear All'),
                                            ),
                                          ],
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed:
                                                _billing.isEmpty ||
                                                    _selectedCustomerId == null
                                                ? null
                                                : () async {
                                                    final messenger =
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        );

                                                    // Build preview lines for the dialog
                                                    final previewLines = _billing
                                                        .map(
                                                          (b) =>
                                                              // InvoiceLine expects name, qty, unitPrice
                                                              InvoiceLine(
                                                                name:
                                                                    b
                                                                        .product
                                                                        ?.name ??
                                                                    'Unknown',
                                                                qty: b.qty,
                                                                unitPrice:
                                                                    b
                                                                        .product
                                                                        ?.sellingPrice ??
                                                                    0.0,
                                                              ),
                                                        )
                                                        .toList();

                                                    // Fetch selected customer to show in dialog (best-effort)
                                                    final customer =
                                                        _selectedCustomerId !=
                                                            null
                                                        ? await _customerService
                                                              .getCustomerById(
                                                                _selectedCustomerId!,
                                                              )
                                                        : null;

                                                    // Show Estimate preview dialog. If user cancels the dialog (closes), abort creation.
                                                    final confirmed =
                                                        await showDialog<bool?>(
                                                          context: context,
                                                          builder: (ctx) =>
                                                              DummyInvoiceDialog(
                                                                lines:
                                                                    previewLines,
                                                                customer:
                                                                    customer,
                                                              ),
                                                        );
                                                    if (confirmed == null) {
                                                      // user closed the dialog; do not create invoice
                                                      return;
                                                    }

                                                    // confirmed is non-null here and indicates paid/unpaid (true=paid, false=unpaid)
                                                    final bool paidChoice =
                                                        confirmed;

                                                    final items = _billing
                                                        .map(
                                                          (b) => {
                                                            'product_id':
                                                                b.product!.id,
                                                            'qty': b.qty,
                                                            'line_total':
                                                                b.lineTotal,
                                                          },
                                                        )
                                                        .toList();
                                                    final total = _billingTotal;

                                                    if (_editingHoldId !=
                                                        null) {
                                                      if (_editingHoldId! > 0) {
                                                        // persisted DB hold -> finalize it with chosen paid flag
                                                        await _customerService
                                                            .finalizeHeldBill(
                                                              _editingHoldId!,
                                                              markPaid:
                                                                  paidChoice,
                                                            );
                                                        _dbHeldBills =
                                                            await _customerService
                                                                .getHeldBills();
                                                      } else {
                                                        // temp in-memory hold: find it and persist as invoice
                                                        final idx = _heldBills
                                                            .indexWhere(
                                                              (h) =>
                                                                  h.id ==
                                                                  _editingHoldId,
                                                            );
                                                        if (idx != -1) {
                                                          final temp =
                                                              _heldBills[idx];
                                                          final itemsForDb = temp
                                                              .items
                                                              .map(
                                                                (b) => {
                                                                  'product_id': b
                                                                      .product
                                                                      ?.id,
                                                                  'qty': b.qty,
                                                                  'line_total':
                                                                      b.lineTotal,
                                                                },
                                                              )
                                                              .toList();
                                                          final totalForDb =
                                                              itemsForDb.fold<
                                                                double
                                                              >(
                                                                0.0,
                                                                (s, it) =>
                                                                    s +
                                                                    (it['line_total']
                                                                            as double? ??
                                                                        0.0),
                                                              );
                                                          await _customerService
                                                              .createCustomerBill(
                                                                customerId:
                                                                    temp.customerId ??
                                                                    _selectedCustomerId!,
                                                                items:
                                                                    itemsForDb,
                                                                total:
                                                                    totalForDb,
                                                                isPaid:
                                                                    paidChoice,
                                                              );
                                                          // remove temp hold
                                                          setState(() {
                                                            _heldBills.removeAt(
                                                              idx,
                                                            );
                                                          });
                                                        }
                                                      }
                                                    } else {
                                                      // No editing hold -> standard create
                                                      await _customerService
                                                          .createCustomerBill(
                                                            customerId:
                                                                _selectedCustomerId!,
                                                            items: items,
                                                            total: total,
                                                            isPaid: paidChoice,
                                                          );
                                                    }

                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Invoice created',
                                                        ),
                                                      ),
                                                    );
                                                    setState(() {
                                                      _billing.clear();
                                                      _editingHoldId = null;
                                                    });
                                                  },
                                            child: const Text('Estimate only'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: _billing.isEmpty
                                                ? null
                                                : () => setState(
                                                    () => _billing.clear(),
                                                  ),
                                            child: const Text('Clear'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ), // Column (body)
          ), // Scaffold
        ), // Focus
      ), // Actions
    ); // Shortcuts
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo / title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store, color: AppColors.surface),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Auto Parts POS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sell faster • Desktop',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Centered search bar (desktop, understated)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    focusNode: _searchFocusNode,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.surfaceMuted.withAlpha(
                            (0.12 * 255).round(),
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _accentColor.withAlpha((0.18 * 255).round()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Shortcuts hint
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Ctrl+Z Reset  •  Ctrl+X Clear',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration get _panelDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(_panelRadius),
    boxShadow: [
      BoxShadow(
        color: const Color.fromRGBO(0, 0, 0, 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
