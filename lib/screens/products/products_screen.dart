import 'package:flutter/material.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../services/product_service.dart';
import 'product_form_dialog.dart';
import 'product_compatibility_dialog.dart';

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
      filtered = filtered.where((product) => product.isActive).toList();
    } else if (_selectedFilter == 'inactive') {
      filtered = filtered.where((product) => !product.isActive).toList();
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

  Future<void> _confirmDeleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${product.name}"?\n\nThis action will hide the product but preserve all data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _productService.deleteProduct(product.id!);

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
              content: Text(result['error'] ?? 'Failed to delete product'),
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
  }

  Future<void> _showCompatibilityDialog(Product product) async {
    await showDialog(
      context: context,
      builder: (context) => ProductCompatibilityDialog(product: product),
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
                      if (product.stockQuantity != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.stockQuantity! > 0
                                ? Colors.green[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stock: ${product.stockQuantity}',
                            style: TextStyle(
                              color: product.stockQuantity! > 0
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (product.sellingPrice != null &&
                          product.sellingPrice! > 0) ...[
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
                  onPressed: () => _showEditProductDialog(product),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _toggleProductStatus(product),
                  icon: Icon(
                    product.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(product.isActive ? 'Deactivate' : 'Activate'),
                  style: TextButton.styleFrom(
                    foregroundColor: product.isActive
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDeleteProduct(product),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Product product) {
    return Chip(
      label: Text(
        product.isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: product.isActive ? Colors.white : Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: product.isActive ? Colors.green : Colors.grey,
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
}
