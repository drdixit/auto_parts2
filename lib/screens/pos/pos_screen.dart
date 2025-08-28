import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/vehicle_model.dart';
import '../../models/manufacturer.dart';
import '../../services/product_service.dart';
import '../../services/main_category_service.dart';
import '../../services/sub_category_service.dart';
import '../../database/database_helper.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class BillingItem {
  final Product product;
  int qty;

  BillingItem({required this.product, this.qty = 1});

  double get lineTotal => (product.sellingPrice ?? 0) * qty;
}

class HeldBill {
  final int id;
  final DateTime createdAt;
  final List<BillingItem> items;
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

  List<MainCategory> _mainCategories = [];
  List<SubCategory> _subCategories = [];
  List<VehicleModel> _vehicles = [];
  List<SubCategory> _visibleSubCategories = [];
  List<VehicleModel> _visibleVehicles = [];
  List<Manufacturer> _manufacturers = [];
  // split lists for vehicle vs product manufacturers
  List<Manufacturer> _vehicleManufacturers = [];
  List<Manufacturer> _productManufacturers = [];
  // legacy/unused: _visibleManufacturers removed (we use context-specific lists)

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // Filters
  int? _selectedMainCategoryId;
  final Set<int> _selectedSubCategoryIds = {};
  final Set<int> _selectedVehicleIds = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Billing
  final List<BillingItem> _billing = [];
  // In-memory held bills (temporary, not persisted)
  final List<HeldBill> _heldBills = [];
  int _nextHoldId = 1;

  void _holdCurrentBill() {
    final copyItems = _billing
        .map((b) => BillingItem(product: b.product, qty: b.qty))
        .toList();

    final hold = HeldBill(
      id: _nextHoldId++,
      createdAt: DateTime.now(),
      items: copyItems,
      searchQuery: _searchQuery,
      selectedMainCategoryId: _selectedMainCategoryId,
      selectedSubCategoryIds: Set.from(_selectedSubCategoryIds),
      selectedVehicleIds: Set.from(_selectedVehicleIds),
      selectedVehicleManufacturerIds: Set.from(_selectedVehicleManufacturerIds),
      selectedProductManufacturerIds: Set.from(_selectedProductManufacturerIds),
    );

    setState(() {
      _heldBills.add(hold);
      _billing.clear(); // start a new bill
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Bill held (#${hold.id})')));
  }

  void _openHeldBills() async {
    if (_heldBills.isEmpty) return;

    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Held Bills'),
          content: SizedBox(
            width: 600,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _heldBills.length,
              itemBuilder: (context, i) {
                final h = _heldBills[i];
                final unique = h.items.length;
                final totalQty = h.items.fold<int>(0, (s, it) => s + it.qty);

                return ListTile(
                  title: Text('$unique item - $totalQty'),
                  subtitle: Text(
                    'Created: ${h.createdAt.toLocal().toString().split('.').first}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(h.id);
                        },
                        child: const Text('Load'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // remove hold
                          setState(() {
                            _heldBills.removeWhere((hb) => hb.id == h.id);
                          });
                          Navigator.of(context).pop(null);
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: _heldBills.isEmpty
                  ? null
                  : () {
                      // Clear all holds and close
                      setState(() {
                        _heldBills.clear();
                      });
                      Navigator.of(context).pop(null);
                    },
              child: const Text('Clear All Holds'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      _loadHeldBill(selected);
    }
  }

  void _loadHeldBill(int id) {
    HeldBill? hold;
    try {
      hold = _heldBills.firstWhere((h) => h.id == id);
    } catch (_) {
      hold = null;
    }
    if (hold == null) return;

    final holdLocal = hold;

    setState(() {
      _billing.clear();
      for (final it in holdLocal.items) {
        _billing.add(BillingItem(product: it.product, qty: it.qty));
      }

      // restore filters/search UI state
      _searchQuery = holdLocal.searchQuery;
      _searchController.text = holdLocal.searchQuery;
      _selectedMainCategoryId = holdLocal.selectedMainCategoryId;
      _selectedSubCategoryIds
        ..clear()
        ..addAll(holdLocal.selectedSubCategoryIds);
      _selectedVehicleIds
        ..clear()
        ..addAll(holdLocal.selectedVehicleIds);
      _selectedVehicleManufacturerIds
        ..clear()
        ..addAll(holdLocal.selectedVehicleManufacturerIds);
      _selectedProductManufacturerIds
        ..clear()
        ..addAll(holdLocal.selectedProductManufacturerIds);
    });

    // remove the hold after loading
    setState(() {
      _heldBills.removeWhere((h) => h.id == id);
    });
  }

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final mainCats = await _mainCatService.getAllCategories();
      final subCats = await _subCatService.getAllSubCategories();

      // Load vehicle models directly from DB (simple and reliable)
      final db = await DatabaseHelper().database;
      final vehicleMaps = await db.query('vehicle_models');
      final vehicles = vehicleMaps.map((m) => VehicleModel.fromMap(m)).toList();
      // Load manufacturers directly from DB
      List<Map<String, dynamic>> manuMaps = [];
      try {
        manuMaps = await db.query('manufacturers');
      } catch (_) {
        manuMaps = [];
      }
      final manufacturers = manuMaps
          .map((m) => Manufacturer.fromMap(m))
          .toList();

      final products = await _productService.getAllProducts();

      setState(() {
        _mainCategories = mainCats;
        _subCategories = subCats;
        _vehicles = vehicles;
        _manufacturers = manufacturers;
        // split manufacturers into vehicle/product contexts using manufacturerType
        _vehicleManufacturers = _manufacturers
            .where(
              (m) =>
                  m.manufacturerType == 'vehicle' ||
                  m.manufacturerType == 'both',
            )
            .toList();
        _productManufacturers = _manufacturers
            .where(
              (m) =>
                  m.manufacturerType == 'parts' || m.manufacturerType == 'both',
            )
            .toList();
        _allProducts = products;
        _visibleSubCategories = _subCategories;
        _visibleVehicles = _vehicles;
      });

      _applyFilters();
    } catch (e) {
      // ignore errors here; UI will show empty lists
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateVisibleForMainCategory() async {
    // Update visible subcategories
    if (_selectedMainCategoryId == null) {
      _visibleSubCategories = _subCategories;
      _visibleVehicles = _vehicles;
    } else {
      _visibleSubCategories = _subCategories
          .where((s) => s.mainCategoryId == _selectedMainCategoryId)
          .toList();

      // Compute vehicles associated with products under this main category
      final productIds = _allProducts
          .where(
            (p) => _visibleSubCategories.any((s) => s.id == p.subCategoryId),
          )
          .map((p) => p.id)
          .whereType<int>()
          .toList();

      if (productIds.isEmpty) {
        _visibleVehicles = [];
      } else {
        final db = await DatabaseHelper().database;
        final placeholders = List.filled(productIds.length, '?').join(',');
        final rows = await db.rawQuery(
          'SELECT DISTINCT vehicle_model_id FROM product_compatibility WHERE product_id IN ($placeholders)',
          productIds,
        );
        final ids = rows
            .map((r) => r['vehicle_model_id'] as int?)
            .whereType<int>()
            .toSet();
        _visibleVehicles = _vehicles.where((v) => ids.contains(v.id)).toList();
      }
    }

    // If manufacturer selections exist, narrow visible vehicles to those manufacturers
    if (_selectedVehicleManufacturerIds.isNotEmpty) {
      _visibleVehicles = _visibleVehicles
          .where(
            (v) => _selectedVehicleManufacturerIds.contains(v.manufacturerId),
          )
          .toList();
    }

    // If no vehicles found, fall back to empty list (UI will reflect)
    if (mounted) setState(() {});
  }

  void _applyFilters() {
    final List<Product> results = [];

    for (final p in _allProducts) {
      // Filter by main category -> check via subCategory main mapping
      if (_selectedMainCategoryId != null) {
        // product.subCategoryId is non-nullable in model; treat 0 as unknown
        if (p.subCategoryId == 0) {
          continue;
        }

        final sub = _subCategories.firstWhere(
          (s) => s.id == p.subCategoryId,
          orElse: () => SubCategory(id: -1, name: '', mainCategoryId: 0),
        );

        if (sub.id == -1 || sub.mainCategoryId != _selectedMainCategoryId) {
          continue;
        }
      }

      // If specific subcategories selected, filter
      if (_selectedSubCategoryIds.isNotEmpty) {
        if (!_selectedSubCategoryIds.contains(p.subCategoryId)) continue;
      }

      // Manufacturer filter
      if (_selectedProductManufacturerIds.isNotEmpty) {
        if (!_selectedProductManufacturerIds.contains(p.manufacturerId)) {
          continue;
        }
      }

      // Vehicle filter: if none selected, include all. If selected, include universals or products that
      // are compatible with at least one selected vehicle. We try to be lightweight and allow products that
      // are marked universal without hitting compatibility table.
      if (_selectedVehicleIds.isNotEmpty) {
        if (p.isUniversal == true) {
          // pass
        } else {
          // naive compatibility check: product_compatibility table lookup
          // To keep this UI responsive we won't await here; instead we'll include product and
          // defer strict filtering to a second pass using synchronous knowledge (best-effort).
          // For now, include the product and rely on server-side joins if available.
        }
      }

      // Search filter (fuzzy)
      if (_searchQuery.isNotEmpty) {
        if (!_fuzzyMatch(p.name, _searchQuery)) continue;
      }

      results.add(p);
    }

    setState(() {
      _filteredProducts = results;
    });
  }

  bool _fuzzyMatch(String? text, String query) {
    if (text == null) return false;
    final s = text.toLowerCase();
    final q = query.toLowerCase();
    // simple subsequence matcher (fast and intuitive for short queries)
    int i = 0;
    for (int j = 0; j < s.length && i < q.length; j++) {
      if (s[j] == q[i]) i++;
    }
    if (i == q.length) return true;

    // fallback: token contains
    return s.contains(q);
  }

  void _toggleSubCategory(int id) {
    setState(() {
      if (_selectedSubCategoryIds.contains(id)) {
        _selectedSubCategoryIds.remove(id);
      } else {
        _selectedSubCategoryIds.add(id);
      }
    });
    _applyFilters();
  }

  void _toggleVehicle(int id) {
    setState(() {
      if (_selectedVehicleIds.contains(id)) {
        _selectedVehicleIds.remove(id);
      } else {
        _selectedVehicleIds.add(id);
      }
    });
    _applyFilters();
  }

  // Manufacturer toggle handled inline for vehicle/product contexts

  // manufacturers selection: separate sets for vehicle vs product manufacturers
  final Set<int> _selectedVehicleManufacturerIds = {};
  final Set<int> _selectedProductManufacturerIds = {};

  void _selectMainCategory(int? id) {
    setState(() {
      _selectedMainCategoryId = id;
      _selectedSubCategoryIds.clear();
    });
    _updateVisibleForMainCategory();
    _applyFilters();
  }

  void _resetAllFilters() {
    setState(() {
      _selectedMainCategoryId = null;
      _selectedSubCategoryIds.clear();
      _selectedVehicleIds.clear();
      _selectedVehicleManufacturerIds.clear();
      _selectedProductManufacturerIds.clear();
      _visibleSubCategories = _subCategories;
      _visibleVehicles = _vehicles;
      _searchQuery = '';
      _searchController.clear();
    });
    // recompute visible vehicles in case manufacturer filters were cleared
    _updateVisibleForMainCategory();
    _applyFilters();
  }

  void _onSearchChanged(String q) {
    setState(() => _searchQuery = q);
    _applyFilters();
  }

  void _addToBilling(Product p) {
    final existing = _billing.firstWhere(
      (b) => b.product.id == p.id,
      orElse: () => BillingItem(product: p, qty: 0),
    );
    if (existing.qty == 0) {
      setState(() => _billing.add(BillingItem(product: p, qty: 1)));
    } else {
      setState(() => existing.qty += 1);
    }
  }

  void _removeFromBilling(Product p) {
    final existing = _billing.firstWhere(
      (b) => b.product.id == p.id,
      orElse: () => BillingItem(product: p, qty: 0),
    );
    if (existing.qty <= 1) {
      setState(() => _billing.removeWhere((b) => b.product.id == p.id));
    } else {
      setState(() => existing.qty -= 1);
    }
  }

  double get _billingTotal => _billing.fold(0.0, (t, b) => t + b.lineTotal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Left: Filters
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Filters',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _resetAllFilters,
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Make the filter content vertically scrollable to avoid RenderFlex overflow
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Main Category'),
                                    const SizedBox(height: 6),
                                    // Use Wrap instead of horizontal scroll to match Sub Categories layout
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        FilterChip(
                                          label: const Text('All'),
                                          selected:
                                              _selectedMainCategoryId == null,
                                          onSelected: (_) =>
                                              _selectMainCategory(null),
                                        ),
                                        ..._mainCategories.map((c) {
                                          return FilterChip(
                                            label: Text(c.name),
                                            selected:
                                                _selectedMainCategoryId == c.id,
                                            onSelected: (_) =>
                                                _selectMainCategory(c.id),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Collapsible Filters
                                    ExpansionTile(
                                      title: const Text('Sub Categories'),
                                      initiallyExpanded: true,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 6.0,
                                          ),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: _visibleSubCategories.map(
                                              (s) {
                                                final selected =
                                                    _selectedSubCategoryIds
                                                        .contains(s.id);
                                                return FilterChip(
                                                  label: Text(s.name),
                                                  selected: selected,
                                                  onSelected: (_) =>
                                                      _toggleSubCategory(s.id!),
                                                );
                                              },
                                            ).toList(),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    ExpansionTile(
                                      title: const Text(
                                        'Vehicle Manufacturers',
                                      ),
                                      initiallyExpanded: false,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 6.0,
                                          ),
                                          child: _vehicleManufacturers.isEmpty
                                              ? const Text('No manufacturers')
                                              : Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: _vehicleManufacturers.map((
                                                    m,
                                                  ) {
                                                    final sel =
                                                        _selectedVehicleManufacturerIds
                                                            .contains(m.id);
                                                    return FilterChip(
                                                      label: Text(m.name),
                                                      selected: sel,
                                                      onSelected: (_) => setState(() {
                                                        if (sel) {
                                                          _selectedVehicleManufacturerIds
                                                              .remove(m.id);
                                                        } else {
                                                          _selectedVehicleManufacturerIds
                                                              .add(m.id!);
                                                        }
                                                        // refresh visible vehicles
                                                        _updateVisibleForMainCategory();
                                                        _applyFilters();
                                                      }),
                                                    );
                                                  }).toList(),
                                                ),
                                        ),
                                      ],
                                    ),

                                    // Product Manufacturers tile moved to the end of filters
                                    const SizedBox(height: 6),

                                    ExpansionTile(
                                      title: const Text('Vehicles'),
                                      initiallyExpanded: false,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 6.0,
                                          ),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: _visibleVehicles.map((v) {
                                              final sel = _selectedVehicleIds
                                                  .contains(v.id);
                                              return FilterChip(
                                                label: Text(v.displayName),
                                                selected: sel,
                                                onSelected: (_) =>
                                                    _toggleVehicle(v.id!),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    ExpansionTile(
                                      title: const Text(
                                        'Product Manufacturers',
                                      ),
                                      initiallyExpanded: false,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                            vertical: 6.0,
                                          ),
                                          child: _productManufacturers.isEmpty
                                              ? const Text('No manufacturers')
                                              : Wrap(
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
                                                        if (sel) {
                                                          _selectedProductManufacturerIds
                                                              .remove(m.id);
                                                        } else {
                                                          _selectedProductManufacturerIds
                                                              .add(m.id!);
                                                        }
                                                        _applyFilters();
                                                      }),
                                                    );
                                                  }).toList(),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Middle: Products + Search
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 6.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search products...',
                                      border: InputBorder.none,
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${_filteredProducts.length} results'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Card(
                            child: _filteredProducts.isEmpty
                                ? const Center(child: Text('No products'))
                                : ListView.builder(
                                    itemCount: _filteredProducts.length,
                                    itemBuilder: (context, i) {
                                      final p = _filteredProducts[i];
                                      final price = p.sellingPrice ?? 0.0;
                                      // quantity in cart for this product
                                      final existingBilling = _billing
                                          .firstWhere(
                                            (b) => b.product.id == p.id,
                                            orElse: () =>
                                                BillingItem(product: p, qty: 0),
                                          );
                                      final int inCartQty = existingBilling.qty;
                                      return ListTile(
                                        leading: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child:
                                              p.primaryImagePath != null &&
                                                  p.primaryImagePath!.isNotEmpty
                                              ? Image.file(
                                                  File(p.primaryImagePath!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const Center(
                                                        child: Text('No image'),
                                                      ),
                                                )
                                              : const Center(
                                                  child: Text('No image'),
                                                ),
                                        ),
                                        title: Text(p.name),
                                        subtitle: Text(
                                          '₹${price.toStringAsFixed(2)}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                              iconSize: 28,
                                              splashRadius: 22,
                                              onPressed: () =>
                                                  _removeFromBilling(p),
                                            ),

                                            // show number of items in cart for this product
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8.0,
                                                    vertical: 4.0,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: inCartQty > 0
                                                    ? Colors.blue.shade50
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '$inCartQty',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: inCartQty > 0
                                                      ? Colors.blue.shade800
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),

                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              iconSize: 28,
                                              splashRadius: 22,
                                              onPressed: () => _addToBilling(p),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right: Billing
                  Expanded(
                    flex: 3,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Billing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _billing.isEmpty
                                  ? const Center(child: Text('No items'))
                                  : ListView.builder(
                                      itemCount: _billing.length,
                                      itemBuilder: (context, i) {
                                        final b = _billing[i];
                                        final unit =
                                            b.product.sellingPrice ?? 0.0;
                                        final lineTotal = unit * b.qty;
                                        return Card(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 6,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // First row: product name
                                                Text(
                                                  b.product.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // Second row: controls and totals (responsive)
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    // Controls group - allow it to size down
                                                    Flexible(
                                                      flex: 0,
                                                      child: Wrap(
                                                        spacing: 6,
                                                        runSpacing: 6,
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          // Move delete to the front for easier access
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.delete,
                                                            ),
                                                            iconSize: 20,
                                                            splashRadius: 18,
                                                            onPressed: () =>
                                                                setState(
                                                                  () => _billing
                                                                      .removeAt(
                                                                        i,
                                                                      ),
                                                                ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.remove,
                                                            ),
                                                            iconSize: 24,
                                                            splashRadius: 18,
                                                            onPressed: () {
                                                              setState(() {
                                                                if (b.qty > 1) {
                                                                  b.qty -= 1;
                                                                } else {
                                                                  _billing
                                                                      .removeAt(
                                                                        i,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade100,
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        6,
                                                                      ),
                                                                ),
                                                            child: Text(
                                                              '${b.qty}',
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons.add,
                                                            ),
                                                            iconSize: 24,
                                                            splashRadius: 18,
                                                            onPressed: () =>
                                                                setState(
                                                                  () => b.qty +=
                                                                      1,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const SizedBox(width: 8),

                                                    // Unit x qty - allow truncation if space is tight
                                                    Expanded(
                                                      child: Text(
                                                        '₹${unit.toStringAsFixed(2)} x ${b.qty}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.black54,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),

                                                    const SizedBox(width: 8),

                                                    // Line total
                                                    Text(
                                                      '₹${lineTotal.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹${_billingTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _billing.isEmpty
                                          ? null
                                          : () => _holdCurrentBill(),
                                      child: const Text('Hold'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _heldBills.isEmpty
                                          ? null
                                          : () => _openHeldBills(),
                                      child: Text(
                                        'Holds (${_heldBills.length})',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _billing.isEmpty
                                          ? null
                                          : () {
                                              // Dummy add: pretend to save or proceed
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Invoice created (dummy)',
                                                  ),
                                                ),
                                              );
                                              setState(() => _billing.clear());
                                            },
                                      child: const Text('Create Invoice'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _billing.isEmpty
                                          ? null
                                          : () => setState(
                                              () => _billing.clear(),
                                            ),
                                      child: const Text('Clear'),
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
                ],
              ),
            ),
    );
  }
}
