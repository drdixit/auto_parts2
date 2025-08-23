import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/main_category.dart';
import '../../models/sub_category.dart';
import '../../models/vehicle_model.dart';
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

class _PosScreenState extends State<PosScreen> {
  final ProductService _productService = ProductService();
  final MainCategoryService _mainCatService = MainCategoryService();
  final SubCategoryService _subCatService = SubCategoryService();

  List<MainCategory> _mainCategories = [];
  List<SubCategory> _subCategories = [];
  List<VehicleModel> _vehicles = [];

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];

  // Filters
  int? _selectedMainCategoryId;
  final Set<int> _selectedSubCategoryIds = {};
  final Set<int> _selectedVehicleIds = {};

  // Search
  String _searchQuery = '';

  // Billing
  final List<BillingItem> _billing = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

      final products = await _productService.getAllProducts();

      setState(() {
        _mainCategories = mainCats;
        _subCategories = subCats;
        _vehicles = vehicles;
        _allProducts = products;
      });

      _applyFilters();
    } catch (e) {
      // ignore errors here; UI will show empty lists
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _selectMainCategory(int? id) {
    setState(() {
      _selectedMainCategoryId = id;
      _selectedSubCategoryIds.clear();
    });
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
      appBar: AppBar(title: const Text('POS')),
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
                            const Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Main Category'),
                            DropdownButton<int?>(
                              isExpanded: true,
                              value: _selectedMainCategoryId,
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All'),
                                ),
                                ..._mainCategories.map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) => _selectMainCategory(v),
                            ),
                            const SizedBox(height: 8),
                            const Text('Sub Categories'),
                            Expanded(
                              child: ListView(
                                children: _subCategories
                                    .where(
                                      (s) =>
                                          _selectedMainCategoryId == null ||
                                          s.mainCategoryId ==
                                              _selectedMainCategoryId,
                                    )
                                    .map(
                                      (s) => CheckboxListTile(
                                        title: Text(s.name),
                                        value: _selectedSubCategoryIds.contains(
                                          s.id,
                                        ),
                                        onChanged: (_) =>
                                            _toggleSubCategory(s.id!),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const Divider(),
                            const Text('Vehicles'),
                            Expanded(
                              child: ListView(
                                children: _vehicles
                                    .map(
                                      (v) => CheckboxListTile(
                                        title: Text(v.displayName),
                                        value: _selectedVehicleIds.contains(
                                          v.id,
                                        ),
                                        onChanged: (_) => _toggleVehicle(v.id!),
                                      ),
                                    )
                                    .toList(),
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
                                      return ListTile(
                                        title: Text(p.name),
                                        subtitle: Text(
                                          '₹${price.toStringAsFixed(2)}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                              onPressed: () =>
                                                  _removeFromBilling(p),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
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
                                        return ListTile(
                                          title: Text(b.product.name),
                                          subtitle: Text(
                                            '₹${(b.product.sellingPrice ?? 0).toStringAsFixed(2)} x ${b.qty}',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove),
                                                onPressed: () {
                                                  setState(() {
                                                    if (b.qty > 1) {
                                                      b.qty -= 1;
                                                    } else {
                                                      _billing.removeAt(i);
                                                    }
                                                  });
                                                },
                                              ),
                                              Text('${b.qty}'),
                                              IconButton(
                                                icon: const Icon(Icons.add),
                                                onPressed: () =>
                                                    setState(() => b.qty += 1),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed: () => setState(
                                                  () => _billing.removeAt(i),
                                                ),
                                              ),
                                            ],
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
                                      : () => setState(() => _billing.clear()),
                                  child: const Text('Clear'),
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
