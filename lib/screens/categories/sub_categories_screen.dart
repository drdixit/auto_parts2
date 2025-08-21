import 'package:flutter/material.dart';
import '../../models/sub_category.dart';
import '../../models/main_category.dart';
import '../../services/sub_category_service.dart';
import '../../services/main_category_service.dart';

class SubCategoriesScreen extends StatefulWidget {
  const SubCategoriesScreen({super.key});

  @override
  State<SubCategoriesScreen> createState() => _SubCategoriesScreenState();
}

class _SubCategoriesScreenState extends State<SubCategoriesScreen> {
  final SubCategoryService _subCategoryService = SubCategoryService();
  final MainCategoryService _mainCategoryService = MainCategoryService();
  List<SubCategory> _subCategories = [];
  List<SubCategory> _filteredSubCategories = [];
  List<MainCategory> _mainCategories = [];
  bool _isLoading = true;
  bool _showInactive = false;
  int? _selectedMainCategoryId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final mainCategories = await _mainCategoryService.getAllCategories();
      final subCategories = _selectedMainCategoryId != null
          ? await _subCategoryService.getSubCategoriesByMainCategory(
              _selectedMainCategoryId!,
              includeInactive: _showInactive,
            )
          : await _subCategoryService.getAllSubCategories(
              includeInactive: _showInactive,
            );

      setState(() {
        _mainCategories = mainCategories;
        _subCategories = subCategories;
        _filteredSubCategories = subCategories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading data: $e');
    }
  }

  void _filterSubCategories(String searchTerm) {
    setState(() {
      if (searchTerm.isEmpty) {
        _filteredSubCategories = _subCategories;
      } else {
        _filteredSubCategories = _subCategories.where((subCategory) {
          return subCategory.name.toLowerCase().contains(
                searchTerm.toLowerCase(),
              ) ||
              (subCategory.description?.toLowerCase().contains(
                    searchTerm.toLowerCase(),
                  ) ??
                  false) ||
              (subCategory.mainCategoryName?.toLowerCase().contains(
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

  Future<void> _toggleSubCategoryStatus(SubCategory subCategory) async {
    try {
      await _subCategoryService.toggleSubCategoryStatus(
        subCategory.id!,
        !subCategory.isActive,
      );
      _loadData();
      _showSuccessSnackBar(
        'Sub-category ${subCategory.isActive ? 'deactivated' : 'activated'} successfully',
      );
    } catch (e) {
      _showErrorSnackBar('Error updating sub-category status: $e');
    }
  }

  void _showAddEditDialog({SubCategory? subCategory}) {
    showDialog(
      context: context,
      builder: (context) => AddEditSubCategoryDialog(
        subCategory: subCategory,
        mainCategories: _mainCategories,
        onSaved: () {
          _loadData();
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
                    hintText: 'Search sub-categories...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _filterSubCategories,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<int?>(
                  value: _selectedMainCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._mainCategories.map((category) {
                      return DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMainCategoryId = value;
                    });
                    _loadData();
                  },
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
                      _loadData();
                    },
                  ),
                  const Text('Show Inactive'),
                ],
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Sub-Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-categories table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubCategories.isEmpty
                ? const Center(child: Text('No sub-categories found'))
                : Card(
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Main Category')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Sort Order')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredSubCategories.map((subCategory) {
                          return DataRow(
                            cells: [
                              DataCell(Text(subCategory.name)),
                              DataCell(
                                Text(subCategory.mainCategoryName ?? ''),
                              ),
                              DataCell(Text(subCategory.description ?? '')),
                              DataCell(Text(subCategory.sortOrder.toString())),
                              DataCell(
                                Chip(
                                  label: Text(
                                    subCategory.isActive
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: subCategory.isActive
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  backgroundColor: subCategory.isActive
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
                                        subCategory: subCategory,
                                      ),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        subCategory.isActive
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () =>
                                          _toggleSubCategoryStatus(subCategory),
                                      tooltip: subCategory.isActive
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

class AddEditSubCategoryDialog extends StatefulWidget {
  final SubCategory? subCategory;
  final List<MainCategory> mainCategories;
  final VoidCallback onSaved;

  const AddEditSubCategoryDialog({
    super.key,
    this.subCategory,
    required this.mainCategories,
    required this.onSaved,
  });

  @override
  State<AddEditSubCategoryDialog> createState() =>
      _AddEditSubCategoryDialogState();
}

class _AddEditSubCategoryDialogState extends State<AddEditSubCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;
  int? _selectedMainCategoryId;
  final SubCategoryService _subCategoryService = SubCategoryService();

  @override
  void initState() {
    super.initState();
    if (widget.subCategory != null) {
      _nameController.text = widget.subCategory!.name;
      _descriptionController.text = widget.subCategory!.description ?? '';
      _sortOrderController.text = widget.subCategory!.sortOrder.toString();
      _isActive = widget.subCategory!.isActive;
      _selectedMainCategoryId = widget.subCategory!.mainCategoryId;
    } else {
      _initializeForNewSubCategory();
    }
  }

  Future<void> _initializeForNewSubCategory() async {
    if (widget.mainCategories.isNotEmpty && _selectedMainCategoryId == null) {
      _selectedMainCategoryId = widget.mainCategories.first.id;
      await _updateSortOrder();
    }
  }

  Future<void> _updateSortOrder() async {
    if (_selectedMainCategoryId != null) {
      final nextSortOrder = await _subCategoryService.getNextSortOrder(
        _selectedMainCategoryId!,
      );
      _sortOrderController.text = nextSortOrder.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _saveSubCategory() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMainCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a main category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if name already exists in the same main category
      final nameExists = await _subCategoryService.isSubCategoryNameExists(
        _nameController.text,
        _selectedMainCategoryId!,
        excludeId: widget.subCategory?.id,
      );

      if (nameExists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sub-category name already exists in this main category',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final subCategory = SubCategory(
        id: widget.subCategory?.id,
        name: _nameController.text,
        mainCategoryId: _selectedMainCategoryId!,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        sortOrder: int.parse(_sortOrderController.text),
        isActive: _isActive,
      );

      if (widget.subCategory == null) {
        await _subCategoryService.insertSubCategory(subCategory);
      } else {
        await _subCategoryService.updateSubCategory(subCategory);
      }

      widget.onSaved();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving sub-category: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.subCategory == null ? 'Add Sub-Category' : 'Edit Sub-Category',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedMainCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Main Category *',
                  border: OutlineInputBorder(),
                ),
                items: widget.mainCategories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a main category';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _selectedMainCategoryId = value;
                  });
                  if (widget.subCategory == null) {
                    _updateSortOrder();
                  }
                },
              ),
              const SizedBox(height: 16),
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
          onPressed: _isLoading ? null : _saveSubCategory,
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
