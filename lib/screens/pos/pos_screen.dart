import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/main_category.dart';
import '../../models/manufacturer.dart';
import '../../models/product.dart';
import '../../models/sub_category.dart';
import '../../models/vehicle_model.dart';
import '../../services/main_category_service.dart';
import '../../services/product_service.dart';
import '../../services/sub_category_service.dart';

// Intents for keyboard shortcuts
class ResetIntent extends Intent {
  const ResetIntent();
}

class ClearBillIntent extends Intent {
  const ClearBillIntent();
}

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
  List<Manufacturer> _productManufacturers = [];

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // Filters
  int? _selectedMainCategoryId;
  final Set<int> _selectedSubCategoryIds = {};
  final Set<int> _selectedVehicleIds = {};
  final Set<int> _selectedVehicleManufacturerIds = {};
  final Set<int> _selectedProductManufacturerIds = {};

  // Search
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Billing
  final List<BillingItem> _billing = [];
  final List<HeldBill> _heldBills = [];
  int _nextHoldId = 1;

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
      final products = await _productService.getAllProducts();

      final db = await DatabaseHelper().database;
      final vehicleMaps = await db.query('vehicle_models');
      final vehicles = vehicleMaps.map((m) => VehicleModel.fromMap(m)).toList();

      List<Map<String, dynamic>> manuMaps = [];
      try {
        manuMaps = await db.query('manufacturers');
      } catch (_) {}
      final manufacturers = manuMaps
          .map((m) => Manufacturer.fromMap(m))
          .toList();

      setState(() {
        _mainCategories = mainCats;
        _subCategories = subCats;
        _vehicles = vehicles;
        _manufacturers = manufacturers;
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
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateVisibleForMainCategory() async {
    if (_selectedMainCategoryId == null) {
      _visibleSubCategories = _subCategories;
      _visibleVehicles = _vehicles;
    } else {
      _visibleSubCategories = _subCategories
          .where((s) => s.mainCategoryId == _selectedMainCategoryId)
          .toList();

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

    if (_selectedVehicleManufacturerIds.isNotEmpty) {
      _visibleVehicles = _visibleVehicles
          .where(
            (v) => _selectedVehicleManufacturerIds.contains(v.manufacturerId),
          )
          .toList();
    }

    if (mounted) setState(() {});
  }

  void _applyFilters() {
    final List<Product> results = [];

    for (final p in _allProducts) {
      if (_selectedMainCategoryId != null) {
        if (p.subCategoryId == 0) continue;

        final sub = _subCategories.firstWhere(
          (s) => s.id == p.subCategoryId,
          orElse: () => SubCategory(id: -1, name: '', mainCategoryId: 0),
        );

        if (sub.id == -1 || sub.mainCategoryId != _selectedMainCategoryId) {
          continue;
        }
      }

      if (_selectedSubCategoryIds.isNotEmpty) {
        if (!_selectedSubCategoryIds.contains(p.subCategoryId)) continue;
      }

      if (_selectedProductManufacturerIds.isNotEmpty) {
        if (!_selectedProductManufacturerIds.contains(p.manufacturerId)) {
          continue;
        }
      }

      if (_selectedVehicleIds.isNotEmpty) {
        if (p.isUniversal == true) {
          // pass
        } else {
          // keep as-is
        }
      }

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
    int i = 0;
    for (int j = 0; j < s.length && i < q.length; j++) {
      if (s[j] == q[i]) i++;
    }
    if (i == q.length) return true;
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
      _billing.clear();
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
                final totalBill = h.items.fold<double>(
                  0.0,
                  (s, it) => s + (it.product.sellingPrice ?? 0) * it.qty,
                );

                return ListTile(
                  title: Text(
                    '$unique items ($totalQty quantity ₹${totalBill.toStringAsFixed(2)})',
                  ),
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
                          setState(
                            () => _heldBills.removeWhere((hb) => hb.id == h.id),
                          );
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
                      setState(() => _heldBills.clear());
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

    if (selected != null) _loadHeldBill(selected);
  }

  void _loadHeldBill(int id) {
    HeldBill? hold;
    try {
      hold = _heldBills.firstWhere((h) => h.id == id);
    } catch (_) {
      hold = null;
    }

    if (hold == null) return;

    final h = hold;

    setState(() {
      _billing.clear();
      _billing.addAll(
        h.items.map((b) => BillingItem(product: b.product, qty: b.qty)),
      );
      _searchQuery = h.searchQuery;
      _searchController.text = h.searchQuery;
      _selectedMainCategoryId = h.selectedMainCategoryId;
      _selectedSubCategoryIds.clear();
      _selectedSubCategoryIds.addAll(h.selectedSubCategoryIds);
      _selectedVehicleIds.clear();
      _selectedVehicleIds.addAll(h.selectedVehicleIds);
      _selectedVehicleManufacturerIds.clear();
      _selectedVehicleManufacturerIds.addAll(h.selectedVehicleManufacturerIds);
      _selectedProductManufacturerIds.clear();
      _selectedProductManufacturerIds.addAll(h.selectedProductManufacturerIds);
    });

    _updateVisibleForMainCategory();
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const ResetIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyX):
            const ClearBillIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ResetIntent: CallbackAction<ResetIntent>(
            onInvoke: (intent) {
              _resetAllFilters();
              _searchController.clear();
              return null;
            },
          ),
          ClearBillIntent: CallbackAction<ClearBillIntent>(
            onInvoke: (intent) {
              if (_billing.isNotEmpty) {
                setState(() => _billing.clear());
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Bill cleared')));
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildTopBar(context),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left: Narrow filter column (desktop-style)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: Container(
                                  decoration: _panelDecoration,
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.tune,
                                            color: Colors.grey[700],
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
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _searchController,
                                        onChanged: _onSearchChanged,
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(Icons.search),
                                          hintText: 'Search products...',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
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
                                                        _selectMainCategory(
                                                          null,
                                                        ),
                                                  ),
                                                  ..._mainCategories.map(
                                                    (c) => FilterChip(
                                                      label: Text(c.name),
                                                      selected:
                                                          _selectedMainCategoryId ==
                                                          c.id,
                                                      onSelected: (_) =>
                                                          _selectMainCategory(
                                                            c.id,
                                                          ),
                                                    ),
                                                  ),
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
                                                children: _visibleSubCategories
                                                    .map(
                                                      (s) => FilterChip(
                                                        label: Text(s.name),
                                                        selected:
                                                            _selectedSubCategoryIds
                                                                .contains(s.id),
                                                        onSelected: (_) =>
                                                            _toggleSubCategory(
                                                              s.id!,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
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
                                                children: _visibleVehicles
                                                    .map(
                                                      (v) => FilterChip(
                                                        label: Text(
                                                          v.displayName,
                                                        ),
                                                        selected:
                                                            _selectedVehicleIds
                                                                .contains(v.id),
                                                        onSelected: (_) =>
                                                            _toggleVehicle(
                                                              v.id!,
                                                            ),
                                                      ),
                                                    )
                                                    .toList(),
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
                                                children: _productManufacturers
                                                    .map(
                                                      (m) => FilterChip(
                                                        label: Text(m.name),
                                                        selected:
                                                            _selectedProductManufacturerIds
                                                                .contains(m.id),
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
                                                      ),
                                                    )
                                                    .toList(),
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
                                                color: Colors.grey[700],
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
                                            final crossAxisCount = (width / 240)
                                                .floor()
                                                .clamp(2, 5);
                                            return _filteredProducts.isEmpty
                                                ? const Center(
                                                    child: Text('No products'),
                                                  )
                                                : GridView.builder(
                                                    gridDelegate:
                                                        SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount:
                                                              crossAxisCount,
                                                          crossAxisSpacing: 8,
                                                          mainAxisSpacing: 8,
                                                          childAspectRatio: 1.2,
                                                        ),
                                                    itemCount: _filteredProducts
                                                        .length,
                                                    itemBuilder: (context, i) {
                                                      final p =
                                                          _filteredProducts[i];
                                                      final price =
                                                          p.sellingPrice ?? 0.0;
                                                      final inCart = _billing
                                                          .where(
                                                            (b) =>
                                                                b.product.id ==
                                                                p.id,
                                                          )
                                                          .fold<int>(
                                                            0,
                                                            (s, b) => s + b.qty,
                                                          );
                                                      return Material(
                                                        color: Colors.white,
                                                        elevation: 0,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child: InkWell(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          onTap: () =>
                                                              _addToBilling(p),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8.0,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Expanded(
                                                                  child: ClipRRect(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                    child:
                                                                        p.primaryImagePath !=
                                                                                null &&
                                                                            p.primaryImagePath!.isNotEmpty
                                                                        ? Image.file(
                                                                            File(
                                                                              p.primaryImagePath!,
                                                                            ),
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            width:
                                                                                double.infinity,
                                                                            errorBuilder:
                                                                                (
                                                                                  _,
                                                                                  __,
                                                                                  ___,
                                                                                ) => Container(
                                                                                  color: Colors.grey[100],
                                                                                  alignment: Alignment.center,
                                                                                  child: const Text(
                                                                                    'No image',
                                                                                  ),
                                                                                ),
                                                                          )
                                                                        : Container(
                                                                            color:
                                                                                Colors.grey[100],
                                                                            alignment:
                                                                                Alignment.center,
                                                                            child: const Text(
                                                                              'No image',
                                                                            ),
                                                                          ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  p.name,
                                                                  maxLines: 2,
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
                                                                  height: 6,
                                                                ),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      '₹${price.toStringAsFixed(2)}',
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .green[700],
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        IconButton(
                                                                          icon: const Icon(
                                                                            Icons.remove_circle_outline,
                                                                          ),
                                                                          onPressed: () =>
                                                                              _removeFromBilling(
                                                                                p,
                                                                              ),
                                                                          splashRadius:
                                                                              18,
                                                                        ),
                                                                        Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                4,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                inCart >
                                                                                    0
                                                                                ? Colors.blue.shade50
                                                                                : Colors.transparent,
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
                                                                          icon: const Icon(
                                                                            Icons.add_circle_outline,
                                                                          ),
                                                                          onPressed: () =>
                                                                              _addToBilling(
                                                                                p,
                                                                              ),
                                                                          splashRadius:
                                                                              18,
                                                                        ),
                                                                      ],
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
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Right: Billing summary (prominent)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: Container(
                                  decoration: _panelDecoration,
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: _billing.isEmpty
                                            ? const Center(
                                                child: Text('No items'),
                                              )
                                            : ListView.builder(
                                                itemCount: _billing.length,
                                                itemBuilder: (context, i) {
                                                  final b = _billing[i];
                                                  return ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Text(
                                                      b.product.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    subtitle: Text(
                                                      '₹${(b.product.sellingPrice ?? 0).toStringAsFixed(2)} x ${b.qty}',
                                                    ),
                                                    trailing: Text(
                                                      '₹${(b.lineTotal).toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                                  color: Colors.green[800],
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _billing.isEmpty
                                                  ? null
                                                  : _holdCurrentBill,
                                              icon: const Icon(
                                                Icons.pause_circle,
                                              ),
                                              label: const Text('Hold'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: _heldBills.isEmpty
                                                  ? null
                                                  : _openHeldBills,
                                              icon: const Icon(
                                                Icons.folder_open,
                                              ),
                                              label: Text(
                                                'Holds (${_heldBills.length})',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _billing.isEmpty
                                                  ? null
                                                  : () {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Invoice created (dummy)',
                                                          ),
                                                        ),
                                                      );
                                                      setState(
                                                        () => _billing.clear(),
                                                      );
                                                    },
                                              child: const Text(
                                                'Create Invoice',
                                              ),
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
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store, color: Colors.white),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
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
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.person, color: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration get _panelDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12.0),
    boxShadow: [
      BoxShadow(
        color: const Color.fromRGBO(0, 0, 0, 0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
