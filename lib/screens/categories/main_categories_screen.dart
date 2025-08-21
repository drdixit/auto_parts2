import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/main_category.dart';
import '../../services/main_category_service.dart';
import '../../database/database_helper.dart';

class MainCategoriesScreen extends StatefulWidget {
  const MainCategoriesScreen({super.key});

  @override
  State<MainCategoriesScreen> createState() => _MainCategoriesScreenState();
}

class _MainCategoriesScreenState extends State<MainCategoriesScreen> {
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
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _categoryService.getAllCategories(
        includeInactive: _showInactive,
      );
      setState(() {
        _categories = categories;
        _filteredCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading categories: $e');
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _toggleCategoryStatus(MainCategory category) async {
    try {
      await _categoryService.toggleCategoryStatus(
        category.id!,
        !category.isActive,
      );
      _loadCategories();
      _showSuccessSnackBar(
        'Category ${category.isActive ? 'deactivated' : 'activated'} successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Error updating category status: $e');
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Header row with search and controls
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

          // Categories table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCategories.isEmpty
                ? const Center(child: Text('No categories found'))
                : Card(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Sort Order')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredCategories.map((category) {
                          return DataRow(
                            cells: [
                              DataCell(Text(category.name)),
                              DataCell(Text(category.description ?? '')),
                              DataCell(Text(category.sortOrder.toString())),
                              DataCell(
                                Chip(
                                  label: Text(
                                    category.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: category.isActive
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  backgroundColor: category.isActive
                                      ? Colors.green
                                      : Colors.grey,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving icon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category name already exists'),
            backgroundColor: Colors.red,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving category: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _iconPath != null ? 'Icon selected' : 'No icon selected',
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _pickIcon,
                    child: const Text('Pick Icon'),
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
