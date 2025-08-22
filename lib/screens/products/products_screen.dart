import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../models/product_inventory.dart';
import '../../services/product_service.dart';
import 'product_form_dialog.dart';
import 'product_compatibility_dialog.dart';
import 'product_inventory_dialog.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, active, inactive

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _productService.getAllProducts(
        includeInactive: true,
      );
      setState(() {
        _products = products;
        _filteredProducts = products;
        _isLoading = false;
      });
      _applyFilters();

      // Auto-fix missing primary images
      _fixMissingPrimaryImages();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fixMissingPrimaryImages() async {
    try {
      final result = await _productService.fixMissingPrimaryImages();
      if (result['success'] && (result['fixedCount'] ?? 0) > 0) {
        // Reload products if any were fixed
        final products = await _productService.getAllProducts(
          includeInactive: true,
        );
        setState(() {
          _products = products;
          _filteredProducts = products;
        });
        _applyFilters();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      print('Error fixing missing primary images: $e');
    }
  }

  void _applyFilters() {
    List<Product> filtered = _products;

    // Apply status filter
    if (_selectedFilter == 'active') {
      filtered = filtered
          .where((product) => product.isEffectivelyActive == true)
          .toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered
          .where((product) => product.isEffectivelyActive != true)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            (product.partNumber?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false) ||
            (product.manufacturerName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false) ||
            (product.subCategoryName?.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ??
                false);
      }).toList();
    }

    setState(() {
      _filteredProducts = filtered;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _applyFilters();
  }

  Future<void> _showAddProductDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ProductFormDialog(),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _showEditProductDialog(Product product) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(product: product),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  Future<void> _toggleProductStatus(Product product) async {
    try {
      final result = await _productService.toggleProductStatus(product.id!);

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        _loadProducts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to update product status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCompatibilityDialog(Product product) async {
    await showDialog(
      context: context,
      builder: (context) => ProductCompatibilityDialog(product: product),
    );
  }

  Future<void> _showInventoryDialog(Product product) async {
    try {
      // Load existing inventory if any
      final inventory = await _productService.getProductInventory(product.id!);

      await showDialog(
        context: context,
        builder: (context) => ProductInventoryDialog(
          productId: product.id!,
          productName: product.name,
          inventory: inventory,
        ),
      );

      // Reload products to refresh any stock/pricing information
      _loadProducts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading inventory: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showQuickStockUpdate(Product product) async {
    final currentStock = product.stockQuantity ?? 0;
    // Treat quick stock input as incoming stock to ADD to current stock
    final stockController = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock - ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Stock: $currentStock units',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Incoming Stock Quantity (to add)',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Note: This will add the entered quantity to the current stock. Use "Inventory" for full inventory edits.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final addedStock = int.tryParse(stockController.text) ?? 0;
              if (addedStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stock quantity cannot be negative'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              final newQuantity = currentStock + addedStock;

              try {
                // If product already has inventory (stockQuantity != null), update it
                if (product.stockQuantity != null) {
                  final result = await _productService.updateStockQuantity(
                    product.id!,
                    newQuantity,
                  );

                  if (result['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message']),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadProducts(); // Refresh the list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['error'] ?? 'Failed to update stock',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  // No inventory exists - create one with the incoming stock using upsert
                  final inventory = ProductInventory(
                    productId: product.id!,
                    stockQuantity: newQuantity,
                  );

                  final result = await _productService.upsertInventory(
                    inventory,
                  );
                  if (result['success']) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Inventory created'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadProducts();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['error'] ?? 'Failed to create inventory',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInventoryOverview() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inventory Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Out of Stock'),
                          Tab(text: 'Low Stock'),
                          Tab(text: 'All Inventory'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildOutOfStockTab(),
                            _buildLowStockTab(),
                            _buildAllInventoryTab(),
                          ],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showInventoryOverview,
            tooltip: 'Inventory Overview',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search products by name, part number, manufacturer...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 12),
                // Filter Chips
                Row(
                  children: [
                    const Text(
                      'Filter: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedFilter == 'all',
                          onSelected: (_) => _onFilterChanged('all'),
                        ),
                        FilterChip(
                          label: const Text('Active'),
                          selected: _selectedFilter == 'active',
                          onSelected: (_) => _onFilterChanged('active'),
                        ),
                        FilterChip(
                          label: const Text('Inactive'),
                          selected: _selectedFilter == 'inactive',
                          onSelected: (_) => _onFilterChanged('inactive'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${_filteredProducts.length} products',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Products List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedFilter != 'all'
                              ? 'No products found matching your criteria'
                              : 'No products available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isNotEmpty || _selectedFilter != 'all')
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                              _onFilterChanged('all');
                            },
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with name and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.partNumber != null &&
                          product.partNumber!.isNotEmpty)
                        Text(
                          'Part No: ${product.partNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(product),
              ],
            ),
            const SizedBox(height: 12),
            // Product details with image
            Row(
              children: [
                // Product Image
                Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: GestureDetector(
                      onTap: () => _showImageDialog(product.primaryImagePath),
                      child: _buildProductImage(product.primaryImagePath),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Category',
                        '${product.mainCategoryName} > ${product.subCategoryName}',
                      ),
                      _buildDetailRow(
                        'Manufacturer',
                        product.manufacturerName ?? 'Unknown',
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty)
                        _buildDetailRow(
                          'Description',
                          product.description!,
                          maxLines: 2,
                        ),
                      if (product.weight != null)
                        _buildDetailRow('Weight', '${product.weight}kg'),
                      if (product.warrantyMonths > 0)
                        _buildDetailRow(
                          'Warranty',
                          '${product.warrantyMonths} months',
                        ),
                      // TODO: Universal fit feature - disabled for future implementation
                      // if (product.isUniversal)
                      //   _buildDetailRow('Fit', 'Universal'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Stock and price info
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Inventory Status
                      _buildInventoryStatus(product),
                      if (product.sellingPrice != null &&
                          product.sellingPrice! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '₹${product.sellingPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showCompatibilityDialog(product),
                  icon: const Icon(Icons.directions_car, size: 16),
                  label: const Text('Vehicles'),
                  style: TextButton.styleFrom(foregroundColor: Colors.purple),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showQuickStockUpdate(product),
                  icon: const Icon(Icons.speed, size: 16),
                  label: const Text('Quick Stock'),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showInventoryDialog(product),
                  icon: const Icon(Icons.inventory_2, size: 16),
                  label: const Text('Inventory'),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showEditProductDialog(product),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _getToggleTooltip(product),
                  child: TextButton.icon(
                    onPressed: _canToggleProduct(product)
                        ? () => _toggleProductStatus(product)
                        : null,
                    icon: Icon(
                      product.isActive
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(product.isActive ? 'Deactivate' : 'Activate'),
                    style: TextButton.styleFrom(
                      foregroundColor: product.isActive
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Product product) {
    // Show clear states with specific category information
    final isEffectivelyActive = product.isEffectivelyActive ?? false;
    final isManuallyDisabled = product.isManuallyDisabled;
    final isProductActive = product.isActive;
    final subCategoryActive = product.subCategoryActive ?? true;
    final mainCategoryActive = product.mainCategoryActive ?? true;

    String statusText;
    Color backgroundColor;
    Color textColor;

    if (isEffectivelyActive) {
      // Product and all parents are active
      statusText = 'Active';
      backgroundColor = Colors.green;
      textColor = Colors.white;
    } else if (!isProductActive) {
      // Product itself is inactive (whether manually disabled or not)
      statusText = 'Inactive';
      backgroundColor = isManuallyDisabled ? Colors.red : Colors.grey;
      textColor = Colors.white;
    } else {
      // Product is active but parent category is inactive
      if (!mainCategoryActive) {
        statusText = 'Inactive by Main Category';
      } else if (!subCategoryActive) {
        statusText = 'Inactive by Sub Category';
      } else {
        statusText = 'Inactive by Category';
      }
      backgroundColor = Colors.orange;
      textColor = Colors.white;
    }

    return Chip(
      label: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildDetailRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      final imageFile = File(imagePath);
      return FutureBuilder<bool>(
        future: imageFile.exists(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return Image.file(
              imageFile,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Error loading image from path: $imagePath');
                print('Error details: $error');
                return _buildImagePlaceholder();
              },
            );
          } else {
            print('Image file does not exist: $imagePath');
            return _buildImagePlaceholder();
          }
        },
      );
    } else {
      print('No image path provided for product');
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey.shade100,
      child: Icon(Icons.image, color: Colors.grey.shade400, size: 32),
    );
  }

  void _showImageDialog(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Product Image'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('Image not found'),
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
      ),
    );
  }

  bool _canToggleProduct(Product product) {
    // Always allow toggling the product's own status
    // The service layer will handle the business logic
    return true;
  }

  String _getToggleTooltip(Product product) {
    final isManuallyDisabled = product.isManuallyDisabled;
    final subCategoryActive = product.subCategoryActive ?? true;
    final mainCategoryActive = product.mainCategoryActive ?? true;

    if (product.isActive) {
      return 'Click to deactivate this product';
    } else if (isManuallyDisabled) {
      if (!subCategoryActive) {
        return 'Product is manually disabled AND sub-category is inactive. Click to activate product.';
      } else if (!mainCategoryActive) {
        return 'Product is manually disabled AND main category is inactive. Click to activate product.';
      } else {
        return 'Product is manually disabled. Click to activate product.';
      }
    } else {
      return 'Product is inactive. Click to activate product.';
    }
  }

  Widget _buildInventoryStatus(Product product) {
    // Check if product has any inventory data at all
    final hasInventoryData =
        product.stockQuantity != null || product.sellingPrice != null;

    if (!hasInventoryData) {
      // No inventory data available
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'No Inventory',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    // Inventory data exists - analyze stock status
    final stockQty = product.stockQuantity ?? 0;
    final sellingPrice = product.sellingPrice ?? 0.0;
    final minimumStockLevel =
        product.minimumStockLevel ?? 5; // Default to 5 if not set

    // Determine stock status using database-driven minimum stock level
    final isOutOfStock = stockQty == 0;
    final isLowStock = stockQty > 0 && stockQty <= minimumStockLevel;
    final isCriticalStock =
        stockQty > 0 &&
        stockQty <= (minimumStockLevel * 0.4).ceil(); // 40% of minimum level

    // Choose appropriate colors and icons
    Color backgroundColor;
    Color foregroundColor;
    IconData icon;
    String statusText;

    if (isOutOfStock) {
      backgroundColor = Colors.red[100]!;
      foregroundColor = Colors.red[800]!;
      icon = Icons.remove_shopping_cart;
      statusText = 'Out of Stock';
    } else if (isCriticalStock) {
      backgroundColor = Colors.red[50]!;
      foregroundColor = Colors.red[700]!;
      icon = Icons.warning;
      statusText = 'Critical: $stockQty';
    } else if (isLowStock) {
      backgroundColor = Colors.orange[100]!;
      foregroundColor = Colors.orange[800]!;
      icon = Icons.warning_amber;
      statusText = 'Low: $stockQty';
    } else {
      backgroundColor = Colors.green[100]!;
      foregroundColor = Colors.green[800]!;
      icon = Icons.inventory_2;
      statusText = 'Stock: $stockQty';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Stock Status Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: foregroundColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: foregroundColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        // Price information if available
        if (sellingPrice > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Text(
              '₹${sellingPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOutOfStockTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productService.getOutOfStockProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final outOfStockProducts = snapshot.data ?? [];

        if (outOfStockProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No products are out of stock!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: outOfStockProducts.length,
          itemBuilder: (context, index) {
            final product = outOfStockProducts[index];
            return ListTile(
              leading: const Icon(
                Icons.remove_shopping_cart,
                color: Colors.red,
              ),
              title: Text(product['name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product['part_number'] != null)
                    Text('Part: ${product['part_number']}'),
                  Text(
                    '${product['manufacturer_name']} - ${product['sub_category_name']}',
                  ),
                ],
              ),
              trailing: Text(
                'Out of Stock',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLowStockTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productService.getLowStockProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final lowStockProducts = snapshot.data ?? [];

        if (lowStockProducts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text(
                  'No products have low stock!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: lowStockProducts.length,
          itemBuilder: (context, index) {
            final product = lowStockProducts[index];
            final stockQty = product['stock_quantity'] ?? 0;
            final minLevel = product['minimum_stock_level'] ?? 5;
            final criticalLevel = (minLevel * 0.4)
                .ceil(); // 40% of minimum level is critical

            return ListTile(
              leading: Icon(
                stockQty <= criticalLevel ? Icons.warning : Icons.warning_amber,
                color: stockQty <= criticalLevel ? Colors.red : Colors.orange,
              ),
              title: Text(product['name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product['part_number'] != null)
                    Text('Part: ${product['part_number']}'),
                  Text(
                    '${product['manufacturer_name']} - ${product['sub_category_name']}',
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Stock: $stockQty',
                    style: TextStyle(
                      color: stockQty <= criticalLevel
                          ? Colors.red[700]
                          : Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Min: $minLevel',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAllInventoryTab() {
    return FutureBuilder<List<ProductInventory>>(
      future: _productService.getAllInventory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final inventoryList = snapshot.data ?? [];

        if (inventoryList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No inventory records found.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: inventoryList.length,
          itemBuilder: (context, index) {
            final inventory = inventoryList[index];
            final stockQty = inventory.stockQuantity;
            final isLowStock = stockQty <= inventory.minimumStockLevel;
            final isOutOfStock = stockQty == 0;

            return ListTile(
              leading: Icon(
                isOutOfStock
                    ? Icons.remove_shopping_cart
                    : isLowStock
                    ? Icons.warning_amber
                    : Icons.inventory_2,
                color: isOutOfStock
                    ? Colors.red
                    : isLowStock
                    ? Colors.orange
                    : Colors.green,
              ),
              title: Text('Product ID: ${inventory.productId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock: $stockQty units'),
                  if (inventory.supplierName != null)
                    Text('Supplier: ${inventory.supplierName}'),
                  if (inventory.locationRack != null)
                    Text('Location: ${inventory.locationRack}'),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (inventory.sellingPrice > 0)
                    Text(
                      '₹${inventory.sellingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  Text(
                    'Min: ${inventory.minimumStockLevel}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
