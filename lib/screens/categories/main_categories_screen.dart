import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:auto_parts2/models/main_category.dart';
import 'package:auto_parts2/services/main_category_service.dart';
import 'package:auto_parts2/database/database_helper.dart';
import 'package:auto_parts2/screens/categories/sub_categories_screen.dart';
import 'package:auto_parts2/screens/products/products_screen.dart';
import 'package:auto_parts2/screens/products/vehicles_screen.dart';
import 'package:auto_parts2/theme/app_colors.dart';

class MainCategoriesScreen extends StatefulWidget {
  const MainCategoriesScreen({super.key});

  @override
  State<MainCategoriesScreen> createState() => _MainCategoriesScreenState();
}

class _MainCategoriesScreenState extends State<MainCategoriesScreen> {
  // Top-level wrapper only; heavy UI lives in `_MainCategoriesTab` below.
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: AppColors.surfaceLight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category, size: 20),
                      SizedBox(width: 8),
                      Text('Main Categories'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Sub-Categories'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Products'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car, size: 20),
                      SizedBox(width: 8),
                      Text('Vehicles'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _MainCategoriesTab(),
                const SubCategoriesScreen(),
                const ProductsScreen(),
                const VehiclesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddEditCategoryDialog extends StatefulWidget {
  final MainCategory? category;
  final VoidCallback onSaved;

  const AddEditCategoryDialog({
    super.key,
    this.category,
    required this.onSaved,
  });

  @override
  State<AddEditCategoryDialog> createState() => _AddEditCategoryDialogState();
}

// Kept-alive tab widget for Main Categories to reduce rebuild/lag when switching tabs
class _MainCategoriesTab extends StatefulWidget {
  const _MainCategoriesTab();

  @override
  State<_MainCategoriesTab> createState() => _MainCategoriesTabState();
}

class _MainCategoriesTabState extends State<_MainCategoriesTab>
    with AutomaticKeepAliveClientMixin {
  final MainCategoryService _categoryService = MainCategoryService();
  List<MainCategory> _categories = [];
  List<MainCategory> _filteredCategories = [];
  bool _isLoading = true;
  bool _showInactive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _categoryService.getAllCategories(
        includeInactive: _showInactive,
      );
      setState(() {
        _categories = cats;
        _filteredCategories = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _filterCategories(String searchTerm) {
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredCategories = _categories;
      } else {
        _filteredCategories = _categories.where((category) {
          return category.name.toLowerCase().contains(
                searchTerm.toLowerCase(),
              ) ||
              (category.description?.toLowerCase().contains(
                    searchTerm.toLowerCase(),
                  ) ??
                  false);
        }).toList();
      }
    });
  }

  Future<void> _toggleCategoryStatus(MainCategory category) async {
    try {
      await _categoryService.toggleCategoryStatus(
        category.id!,
        !category.isActive,
      );
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Category ${category.isActive ? 'deactivated' : 'activated'} successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddEditDialog({MainCategory? category}) {
    showDialog(
      context: context,
      builder: (context) => AddEditCategoryDialog(
        category: category,
        onSaved: () {
          _loadCategories();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildImagePreview(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceMuted),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 20,
              color: AppColors.textSecondary,
            ),
            Text(
              'No Image',
              style: TextStyle(fontSize: 8, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) =>
              Dialog(child: Image.file(File(iconPath), fit: BoxFit.contain)),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceMuted),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Image.file(
            File(iconPath),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _filterCategories,
                ),
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Checkbox(
                    value: _showInactive,
                    onChanged: (value) {
                      setState(() {
                        _showInactive = value ?? false;
                      });
                      _loadCategories();
                    },
                  ),
                  const Text('Show Inactive'),
                ],
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                ? const Center(child: Text('No categories found'))
                : Card(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Image')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Sort Order')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredCategories.map((category) {
                          return DataRow(
                            cells: [
                              DataCell(_buildImagePreview(category.iconPath)),
                              DataCell(Text(category.name)),
                              DataCell(Text(category.description ?? '')),
                              DataCell(Text(category.sortOrder.toString())),
                              DataCell(
                                Chip(
                                  label: Text(
                                    category.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: category.isActive
                                          ? AppColors.surface
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  backgroundColor: category.isActive
                                      ? AppColors.success
                                      : AppColors.surfaceMuted,
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showAddEditDialog(
                                        category: category,
                                      ),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        category.isActive
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () =>
                                          _toggleCategoryStatus(category),
                                      tooltip: category.isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _AddEditCategoryDialogState extends State<AddEditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;
  String? _iconPath;
  final MainCategoryService _categoryService = MainCategoryService();

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descriptionController.text = widget.category!.description ?? '';
      _sortOrderController.text = widget.category!.sortOrder.toString();
      _isActive = widget.category!.isActive;
      _iconPath = widget.category!.iconPath;
    } else {
      _initializeForNewCategory();
    }
  }

  Future<void> _initializeForNewCategory() async {
    final nextSortOrder = await _categoryService.getNextSortOrder();
    _sortOrderController.text = nextSortOrder.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      try {
        final sourcePath = result.files.single.path!;
        final dbHelper = DatabaseHelper();
        final imagesDir = await dbHelper.getImagesDirectoryPath();
        final fileName =
            'icon_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension}';
        final targetPath = '$imagesDir/$fileName';

        await File(sourcePath).copy(targetPath);

        setState(() {
          _iconPath = targetPath;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving icon: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildImagePreviewInDialog(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 32,
              color: AppColors.surfaceMuted,
            ),
            const SizedBox(height: 4),
            Text(
              'No Image',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(iconPath),
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 100,
            height: 100,
            color: AppColors.surfaceMuted.withAlpha((0.12 * 255).round()),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 32, color: AppColors.error),
                const SizedBox(height: 4),
                Text(
                  'Error Loading',
                  style: TextStyle(fontSize: 10, color: AppColors.error),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if name already exists
      final nameExists = await _categoryService.isCategoryNameExists(
        _nameController.text,
        excludeId: widget.category?.id,
      );

      if (nameExists) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category name already exists')),
          );
        }
        return;
      }

      final category = MainCategory(
        id: widget.category?.id,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        iconPath: _iconPath,
        sortOrder: int.parse(_sortOrderController.text),
        isActive: _isActive,
      );

      if (widget.category == null) {
        await _categoryService.insertCategory(category);
      } else {
        await _categoryService.updateCategory(category);
      }

      widget.onSaved();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving category: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(
                  labelText: 'Sort Order *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Sort order is required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Icon',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _buildImagePreviewInDialog(_iconPath),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickIcon,
                              icon: const Icon(Icons.image),
                              label: Text(
                                _iconPath != null ? 'Change Icon' : 'Pick Icon',
                              ),
                            ),
                            if (_iconPath != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _iconPath = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Remove Icon',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value ?? true;
                      });
                    },
                  ),
                  const Text('Active'),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCategory,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
