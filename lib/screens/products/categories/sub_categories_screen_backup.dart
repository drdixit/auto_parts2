import 'package:flutter/material.dart';
import 'dart:io';
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
  List<MainCategory> _allMainCategories =
      []; // Includes inactive categories for dialogs
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
      // For the dropdown filter, only show active categories
      final mainCategories = await _mainCategoryService.getAllCategories();
      // For dialogs, we need all categories (including inactive) to allow editing existing sub-categories
      final allMainCategories = await _mainCategoryService.getAllCategories(
        includeInactive: true,
      );
      final subCategories = await _subCategoryService.getAllSubCategories();

      setState(() {
        _mainCategories = mainCategories;
        _allMainCategories =
            allMainCategories; // Store all categories for dialogs
        _subCategories = subCategories;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    List<SubCategory> filtered = _subCategories;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((subCategory) {
        final mainCategoryName = _allMainCategories
            .firstWhere(
              (mainCat) => mainCat.id == subCategory.mainCategoryId,
              orElse: () => MainCategory(
                id: 0,
                name: 'Unknown',
                sortOrder: 0,
                isActive: false,
              ),
            )
            .name
            .toLowerCase();

        return subCategory.name.toLowerCase().contains(query) ||
            (subCategory.description?.toLowerCase().contains(query) ?? false) ||
            mainCategoryName.contains(query);
      }).toList();
    }

    // Apply main category filter
    if (_selectedMainCategoryId != null) {
      filtered = filtered
          .where(
            (subCategory) =>
                subCategory.mainCategoryId == _selectedMainCategoryId,
          )
          .toList();
    }

    // Apply active/inactive filter
    if (!_showInactive) {
      filtered = filtered.where((subCategory) => subCategory.isActive).toList();
    }

    // Sort by sort order
    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    setState(() {
      _filteredSubCategories = filtered;
    });
  }

  Future<void> _deleteSubCategory(SubCategory subCategory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sub-Category'),
        content: Text(
          'Are you sure you want to delete "${subCategory.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _subCategoryService.deleteSubCategory(subCategory.id!);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sub-category deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting sub-category: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleSubCategoryStatus(SubCategory subCategory) async {
    try {
      final updatedSubCategory = SubCategory(
        id: subCategory.id,
        name: subCategory.name,
        description: subCategory.description,
        mainCategoryId: subCategory.mainCategoryId,
        sortOrder: subCategory.sortOrder,
        isActive: !subCategory.isActive,
        updatedAt: DateTime.now(),
      );

      await _subCategoryService.updateSubCategory(updatedSubCategory);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sub-category ${subCategory.isActive ? 'deactivated' : 'activated'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sub-category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditDialog({SubCategory? subCategory}) {
    showDialog(
      context: context,
      builder: (context) => AddEditSubCategoryDialog(
        subCategory: subCategory,
        mainCategories:
            _allMainCategories, // Use all categories including inactive ones
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
          // Header
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Sub-Categories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Sub-Category'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filters
          Row(
            children: [
              // Search
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search sub-categories...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 16),

              // Main Category Filter
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _selectedMainCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Main Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._mainCategories.map((category) {
                      return DropdownMenuItem(
                        value: category.id,
                        child: Row(
                          children: [
                            if (category.iconPath != null &&
                                category.iconPath!.isNotEmpty)
                              Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Image.file(
                                    File(category.iconPath!),
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 10,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                category.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMainCategoryId = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),

              // Show Inactive Toggle
              Row(
                children: [
                  Checkbox(
                    value: _showInactive,
                    onChanged: (value) {
                      setState(() {
                        _showInactive = value ?? false;
                      });
                      _applyFilters();
                    },
                  ),
                  const Text('Show Inactive'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubCategories.isEmpty
                ? const Center(
                    child: Text(
                      'No sub-categories found.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredSubCategories.length,
                    itemBuilder: (context, index) {
                      final subCategory = _filteredSubCategories[index];
                      final mainCategory = _allMainCategories.firstWhere(
                        (cat) => cat.id == subCategory.mainCategoryId,
                        orElse: () => MainCategory(
                          id: 0,
                          name: 'Unknown',
                          sortOrder: 0,
                          isActive: false,
                        ),
                      );

                      return Card(
                        child: ListTile(
                          leading: _buildMainCategoryImage(mainCategory),
                          title: Text(
                            subCategory.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              decoration: subCategory.isActive
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: subCategory.isActive
                                  ? null
                                  : Colors.grey[600],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Main Category: ${mainCategory.name}',
                                style: TextStyle(
                                  color: mainCategory.isActive
                                      ? null
                                      : Colors.red[600],
                                  decoration: mainCategory.isActive
                                      ? null
                                      : TextDecoration.lineThrough,
                                ),
                              ),
                              if (subCategory.description != null &&
                                  subCategory.description!.isNotEmpty)
                                Text(subCategory.description!),
                              Text(
                                'Sort Order: ${subCategory.sortOrder}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!subCategory.isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Inactive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    onTap: () => _showAddEditDialog(
                                      subCategory: subCategory,
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () =>
                                        _toggleSubCategoryStatus(subCategory),
                                    child: Row(
                                      children: [
                                        Icon(
                                          subCategory.isActive
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          subCategory.isActive
                                              ? 'Deactivate'
                                              : 'Activate',
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    onTap: () =>
                                        _deleteSubCategory(subCategory),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
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
        ],
      ),
    );
  }

  Widget _buildMainCategoryImage(MainCategory category) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: category.iconPath != null && category.iconPath!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.file(
                File(category.iconPath!),
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.broken_image,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            )
          : Container(
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                  Text(
                    'No Image',
                    style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryDropdownItem(
    MainCategory category, {
    bool isSelected = false,
    bool showInactiveState = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: category.iconPath != null && category.iconPath!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.file(
                    File(category.iconPath!),
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  color: Colors.grey[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 8,
                        color: Colors.grey[400],
                      ),
                      Text(
                        'No Image',
                        style: TextStyle(fontSize: 4, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: showInactiveState
                        ? Colors.grey[600]
                        : (isSelected ? Colors.blue : null),
                    fontWeight: isSelected ? FontWeight.w500 : null,
                    decoration: showInactiveState
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showInactiveState)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
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
    if (widget.mainCategories.isNotEmpty) {
      // Use microtask to avoid potential timing issues
      Future.microtask(() async {
        if (mounted) {
          await _updateSortOrder();
        }
      });
    }
  }

  Future<void> _updateSortOrder() async {
    if (_selectedMainCategoryId == null) return;

    try {
      final subCategoryService = SubCategoryService();
      final nextSortOrder = await subCategoryService.getNextSortOrder(
        _selectedMainCategoryId!,
      );
      if (mounted) {
        setState(() {
          _sortOrderController.text = nextSortOrder.toString();
        });
      }
    } catch (e) {
      // If error occurs, default to 1
      if (mounted) {
        setState(() {
          _sortOrderController.text = '1';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Widget _buildCategoryDropdownItem(
    MainCategory category, {
    bool isSelected = false,
    bool showInactiveState = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: category.iconPath != null && category.iconPath!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.file(
                    File(category.iconPath!),
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  color: Colors.grey[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 8,
                        color: Colors.grey[400],
                      ),
                      Text(
                        'No Image',
                        style: TextStyle(fontSize: 4, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: showInactiveState
                        ? Colors.grey[600]
                        : (isSelected ? Colors.blue : null),
                    fontWeight: isSelected ? FontWeight.w500 : null,
                    decoration: showInactiveState
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showInactiveState)
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
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
      final subCategoryService = SubCategoryService();
      final subCategory = SubCategory(
        id: widget.subCategory?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        mainCategoryId: _selectedMainCategoryId!,
        sortOrder: int.parse(_sortOrderController.text),
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );

      if (widget.subCategory == null) {
        await subCategoryService.insertSubCategory(subCategory);
      } else {
        await subCategoryService.updateSubCategory(subCategory);
      }

      if (mounted) {
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sub-category ${widget.subCategory == null ? 'added' : 'updated'} successfully',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving sub-category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.subCategory == null ? 'Add Sub-Category' : 'Edit Sub-Category',
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 500
              ? 400
              : MediaQuery.of(context).size.width * 0.8,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedMainCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Main Category *',
                    border: OutlineInputBorder(),
                  ),
                  selectedItemBuilder: (context) {
                    return widget.mainCategories.map((category) {
                      return _buildCategoryDropdownItem(
                        category,
                        isSelected: true,
                        showInactiveState: !category.isActive,
                      );
                    }).toList();
                  },
                  items: widget.mainCategories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      enabled:
                          category.isActive ||
                          (widget.subCategory != null &&
                              widget.subCategory!.mainCategoryId ==
                                  category.id),
                      child: _buildCategoryDropdownItem(
                        category,
                        showInactiveState: !category.isActive,
                      ),
                    );
                  }).toList(),
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a main category';
                    }
                    // For new sub-categories, prevent selection of inactive main categories
                    if (widget.subCategory == null) {
                      final selectedCategory = widget.mainCategories.firstWhere(
                        (cat) => cat.id == value,
                        orElse: () => MainCategory(
                          id: 0,
                          name: '',
                          sortOrder: 0,
                          isActive: false,
                        ),
                      );
                      if (!selectedCategory.isActive) {
                        return 'Cannot select inactive main category for new sub-category';
                      }
                    }
                    return null;
                  },
                  onChanged: (value) {
                    // For new sub-categories, prevent selection of inactive main categories
                    if (widget.subCategory == null && value != null) {
                      final selectedCategory = widget.mainCategories.firstWhere(
                        (cat) => cat.id == value,
                        orElse: () => MainCategory(
                          id: 0,
                          name: '',
                          sortOrder: 0,
                          isActive: false,
                        ),
                      );
                      if (!selectedCategory.isActive) {
                        // Delay the SnackBar to avoid mouse tracker assertion error
                        Future.microtask(() {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cannot select inactive main category',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        });
                        return; // Don't change the selection
                      }
                    }

                    setState(() {
                      _selectedMainCategoryId = value;
                    });
                    if (widget.subCategory == null) {
                      // Use microtask to avoid potential timing issues
                      Future.microtask(() async {
                        if (mounted) {
                          await _updateSortOrder();
                        }
                      });
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
