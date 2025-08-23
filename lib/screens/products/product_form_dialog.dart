import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/product.dart';
import '../../models/manufacturer.dart';
import '../../models/sub_category.dart';
import '../../models/product_image.dart';
import '../../models/vehicle_model.dart';
import '../../models/product_compatibility.dart';
import '../../services/product_service.dart';

class ProductFormDialog extends StatefulWidget {
  final Product? product;

  const ProductFormDialog({super.key, this.product});

  bool get isEditing => product != null;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();

  // Product form controllers
  final _nameController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _specificationsController = TextEditingController();
  final _weightController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _materialController = TextEditingController();
  final _warrantyController = TextEditingController();

  // Dropdown values
  int? _selectedSubCategoryId;
  int? _selectedManufacturerId;
  bool _isUniversal = false;
  bool _isActive = true;
  bool _originalIsActive = true; // Track original status for editing

  // Options
  List<SubCategory> _subCategories = [];
  List<Manufacturer> _manufacturers = [];

  // Vehicle compatibility
  List<VehicleModel> _allVehicles = [];
  List<VehicleModel> _filteredVehicles = [];
  Set<int> _selectedVehicleIds = {};
  final TextEditingController _vehicleSearchController =
      TextEditingController();

  // Image handling
  List<ProductImage> _productImages = [];
  List<String> _selectedImagePaths = [];
  int? _primaryImageIndex;

  // State
  bool _isLoading = false;
  bool _isLoadingData = true;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _loadFormData();
    _initializeForm();
  }

  @override
  void dispose() {
    // Product controllers
    _nameController.dispose();
    _partNumberController.dispose();
    _descriptionController.dispose();
    _specificationsController.dispose();
    _weightController.dispose();
    _dimensionsController.dispose();
    _materialController.dispose();
    _warrantyController.dispose();
    _vehicleSearchController.dispose();

    super.dispose();
  }

  void _initializeForm() {
    if (widget.product != null) {
      final product = widget.product!;
      _nameController.text = product.name;
      _partNumberController.text = product.partNumber ?? '';
      _descriptionController.text = product.description ?? '';
      _specificationsController.text = product.specifications ?? '';
      _weightController.text = product.weight?.toString() ?? '';
      _dimensionsController.text = product.dimensions ?? '';
      _materialController.text = product.material ?? '';
      _warrantyController.text = product.warrantyMonths.toString();

      _selectedSubCategoryId = product.subCategoryId;
      _selectedManufacturerId = product.manufacturerId;
      _isUniversal = product.isUniversal;
      _isActive = product.isActive;
      _originalIsActive = product.isActive; // Store original status

      // Load existing images
      _loadProductImages();
    } else {
      // Default values for new product
      _warrantyController.text = '0';
      _originalIsActive = true; // New products start as active
    }
  }

  Future<void> _loadProductImages() async {
    if (widget.product?.id != null) {
      try {
        final images = await _productService.getProductImages(
          widget.product!.id!,
        );
        setState(() {
          _productImages = images;
          _selectedImagePaths = images.map((img) => img.imagePath).toList();
          _primaryImageIndex = images.indexWhere((img) => img.isPrimary);
          if (_primaryImageIndex == -1) {
            _primaryImageIndex = images.isNotEmpty
                ? 0
                : null; // Set first image as primary if none is set
          }
        });
      } catch (e) {
        // Handle error silently or show snackbar
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImagePaths.addAll(
            result.files.map((file) => file.path!).toList(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImagePaths.removeAt(index);
      if (_primaryImageIndex == index) {
        _primaryImageIndex = null;
      } else if (_primaryImageIndex != null && _primaryImageIndex! > index) {
        _primaryImageIndex = _primaryImageIndex! - 1;
      }
    });
  }

  void _setPrimaryImage(int index) {
    setState(() {
      _primaryImageIndex = index;
    });
  }

  Future<void> _loadFormData() async {
    try {
      final subCategories = await _productService.getActiveSubCategories();
      final manufacturers = await _productService.getPartsManufacturers();
      final vehicles = await _productService.getAllVehicleModels();

      // Load existing vehicle compatibility if editing
      List<ProductCompatibility> existingCompatibilities = [];
      if (widget.product?.id != null) {
        existingCompatibilities = await _productService.getProductCompatibility(
          widget.product!.id!,
        );
      }

      setState(() {
        _subCategories = subCategories;
        _manufacturers = manufacturers;
        _allVehicles = vehicles;
        _filteredVehicles = vehicles;
        _selectedVehicleIds = existingCompatibilities
            .map((c) => c.vehicleModelId)
            .toSet();
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading form data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterVehicles(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVehicles = _allVehicles;
      } else {
        _filteredVehicles = _allVehicles.where((vehicle) {
          final searchQuery = query.toLowerCase();
          final manufacturerName =
              vehicle.manufacturerName?.toLowerCase() ?? '';
          final vehicleName = vehicle.name.toLowerCase();
          final vehicleType = vehicle.vehicleTypeName?.toLowerCase() ?? '';
          final year = vehicle.modelYear?.toString() ?? '';
          final capacity = vehicle.engineCapacity?.toLowerCase() ?? '';

          return manufacturerName.contains(searchQuery) ||
              vehicleName.contains(searchQuery) ||
              vehicleType.contains(searchQuery) ||
              year.contains(searchQuery) ||
              capacity.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _toggleVehicleCompatibility(int vehicleId, bool selected) {
    setState(() {
      if (selected) {
        _selectedVehicleIds.add(vehicleId);
      } else {
        _selectedVehicleIds.remove(vehicleId);
      }
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubCategoryId == null) {
      setState(() {
        _fieldErrors['sub_category_id'] = 'Please select a sub-category';
      });
      return;
    }

    if (_selectedManufacturerId == null) {
      setState(() {
        _fieldErrors['manufacturer_id'] = 'Please select a manufacturer';
      });
      return;
    }

    // Additional validation for numeric fields
    if (_weightController.text.trim().isNotEmpty) {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight == null) {
        setState(() {
          _fieldErrors['weight'] = 'Invalid weight format';
        });
        return;
      }
      if (weight < 0) {
        setState(() {
          _fieldErrors['weight'] = 'Weight cannot be negative';
        });
        return;
      }
      if (weight > 1000) {
        setState(() {
          _fieldErrors['weight'] = 'Weight cannot exceed 1000 kg';
        });
        return;
      }
    }

    final warranty = int.tryParse(_warrantyController.text.trim());
    if (warranty == null) {
      setState(() {
        _fieldErrors['warranty_months'] = 'Invalid warranty format';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clear();
    });

    try {
      // Determine if manually disabled
      bool isManuallyDisabled;
      if (widget.isEditing) {
        // For editing: manually disabled if user changed active status to false
        isManuallyDisabled = !_isActive && (_originalIsActive != _isActive);
      } else {
        // For new products: manually disabled if user unchecked active
        isManuallyDisabled = !_isActive;
      }

      final product = Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        partNumber: _partNumberController.text.trim().isEmpty
            ? null
            : _partNumberController.text.trim(),
        subCategoryId: _selectedSubCategoryId!,
        manufacturerId: _selectedManufacturerId!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        specifications: _specificationsController.text.trim().isEmpty
            ? null
            : _specificationsController.text.trim(),
        weight: _weightController.text.trim().isEmpty
            ? null
            : double.tryParse(_weightController.text.trim()),
        dimensions: _dimensionsController.text.trim().isEmpty
            ? null
            : _dimensionsController.text.trim(),
        material: _materialController.text.trim().isEmpty
            ? null
            : _materialController.text.trim(),
        warrantyMonths: warranty,
        isUniversal: _isUniversal,
        isActive: _isActive,
        isManuallyDisabled: isManuallyDisabled,
      );

      Map<String, dynamic> result;
      if (widget.isEditing) {
        result = await _productService.updateProduct(product);
      } else {
        result = await _productService.createProduct(product);
      }

      if (result['success']) {
        final productId = result['id'] ?? widget.product?.id;

        // Handle images if any are selected
        if (_selectedImagePaths.isNotEmpty && productId != null) {
          debugPrint(
            'Processing ${_selectedImagePaths.length} images for product $productId',
          );
          debugPrint('Selected image paths: $_selectedImagePaths');
          debugPrint('Primary image index: $_primaryImageIndex');

          // If no primary image is selected, set the first image as primary
          if (_primaryImageIndex == null && _selectedImagePaths.isNotEmpty) {
            _primaryImageIndex = 0;
            debugPrint('Auto-setting first image as primary (index: 0)');
          }

          // Copy images to app directory
          List<String> copiedImagePaths = [];

          for (String imagePath in _selectedImagePaths) {
            String? copiedPath;

            // Check if it's an existing image (already in app directory)
            if (_productImages.any((img) => img.imagePath == imagePath)) {
              debugPrint('Using existing image: $imagePath');
              copiedPath = imagePath; // Keep existing path
            } else {
              debugPrint('Copying new image: $imagePath');
              // Copy new image to app directory
              copiedPath = await _productService.copyImageToAppDirectory(
                imagePath,
              );
            }

            if (copiedPath != null) {
              debugPrint('Image processed successfully: $copiedPath');
              copiedImagePaths.add(copiedPath);
            } else {
              debugPrint('Failed to process image: $imagePath');
            }
          }

          debugPrint('Final copied image paths: $copiedImagePaths');

          // Save images to database
          final imageResult = await _productService.saveProductImages(
            productId,
            copiedImagePaths,
            _primaryImageIndex,
          );

          debugPrint('Image save result: $imageResult');
        }

        // Save vehicle compatibility after product is saved
        try {
          final savedProductId = productId;
          if (savedProductId != null) {
            // Get current compatibility to compare
            final currentCompatibility = await _productService
                .getProductCompatibility(savedProductId);
            final currentVehicleIds = currentCompatibility
                .map((c) => c.vehicleModelId)
                .toSet();

            // Find vehicles to add and remove
            final toAdd = _selectedVehicleIds.difference(currentVehicleIds);
            final toRemove = currentVehicleIds.difference(_selectedVehicleIds);

            // Remove unselected vehicles
            for (final vehicleId in toRemove) {
              final compatibilityToRemove = currentCompatibility.firstWhere(
                (c) => c.vehicleModelId == vehicleId,
              );
              if (compatibilityToRemove.id != null) {
                await _productService.removeProductCompatibility(
                  compatibilityToRemove.id!,
                );
              }
            }

            // Add newly selected vehicles
            for (final vehicleId in toAdd) {
              final newCompatibility = ProductCompatibility(
                id: 0, // Will be auto-assigned
                productId: savedProductId,
                vehicleModelId: vehicleId,
              );
              await _productService.addProductCompatibility(newCompatibility);
            }
          }
        } catch (e) {
          // Log error but don't prevent success notification
          debugPrint('Error saving vehicle compatibility: $e');
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isLoading = false;
          if (result['errors'] != null) {
            _fieldErrors = Map<String, String>.from(result['errors']);
          }
        });

        if (result['error'] != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = (screenHeight * 0.9).clamp(700.0, 900.0);

    return Dialog(
      child: Container(
        width: 700,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        widget.isEditing ? Icons.edit : Icons.add,
                        color: Colors.blue,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.isEditing ? 'Edit Product' : 'Add New Product',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Form
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic Information Section
                            _buildSectionHeader('Basic Information'),
                            const SizedBox(height: 16),

                            // Product Name
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Product Name *',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['name'],
                                helperText:
                                    'Enter the full product name (3-200 characters)',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Product name is required';
                                }
                                final trimmedValue = value.trim();
                                if (trimmedValue.length < 3) {
                                  return 'Product name must be at least 3 characters';
                                }
                                if (trimmedValue.length > 200) {
                                  return 'Product name must not exceed 200 characters';
                                }
                                // Check for special characters that might cause issues
                                if (trimmedValue.contains(
                                  RegExp(r'[<>"\\\[\]{}|`~]'),
                                )) {
                                  return 'Product name contains invalid characters';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                // Clear field error when user starts typing
                                if (_fieldErrors.containsKey('name')) {
                                  setState(() {
                                    _fieldErrors.remove('name');
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Part Number
                            TextFormField(
                              controller: _partNumberController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Part Number',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['part_number'],
                                helperText:
                                    'Manufacturer part number (optional, max 100 chars)',
                              ),
                              validator: (value) {
                                if (value != null && value.trim().isNotEmpty) {
                                  final trimmedValue = value.trim();
                                  if (trimmedValue.length > 100) {
                                    return 'Part number must not exceed 100 characters';
                                  }
                                  // Allow alphanumeric, hyphens, underscores, periods
                                  if (!RegExp(
                                    r'^[a-zA-Z0-9\-_.]+$',
                                  ).hasMatch(trimmedValue)) {
                                    return 'Part number can only contain letters, numbers, hyphens, underscores, and periods';
                                  }
                                }
                                return null;
                              },
                              onChanged: (value) {
                                // Clear field error when user starts typing
                                if (_fieldErrors.containsKey('part_number')) {
                                  setState(() {
                                    _fieldErrors.remove('part_number');
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Sub Category and Manufacturer Row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue:
                                        _subCategories.any(
                                          (cat) =>
                                              cat.id == _selectedSubCategoryId,
                                        )
                                        ? _selectedSubCategoryId
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Sub Category *',
                                      border: const OutlineInputBorder(),
                                      errorText:
                                          _fieldErrors['sub_category_id'],
                                    ),
                                    items: _subCategories
                                        .fold<Map<int, dynamic>>({}, (
                                          map,
                                          subCategory,
                                        ) {
                                          map[subCategory.id!] = subCategory;
                                          return map;
                                        })
                                        .values
                                        .map((subCategory) {
                                          return DropdownMenuItem<int>(
                                            value: subCategory.id,
                                            child: Text(
                                              '${subCategory.mainCategoryName} > ${subCategory.name}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedSubCategoryId = value;
                                        _fieldErrors.remove('sub_category_id');
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a sub-category';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue:
                                        _manufacturers.any(
                                          (man) =>
                                              man.id == _selectedManufacturerId,
                                        )
                                        ? _selectedManufacturerId
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Manufacturer *',
                                      border: const OutlineInputBorder(),
                                      errorText:
                                          _fieldErrors['manufacturer_id'],
                                    ),
                                    items: _manufacturers
                                        .fold<Map<int, dynamic>>({}, (
                                          map,
                                          manufacturer,
                                        ) {
                                          map[manufacturer.id!] = manufacturer;
                                          return map;
                                        })
                                        .values
                                        .map((manufacturer) {
                                          return DropdownMenuItem<int>(
                                            value: manufacturer.id,
                                            child: Text(
                                              manufacturer.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedManufacturerId = value;
                                        _fieldErrors.remove('manufacturer_id');
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a manufacturer';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Description Section
                            _buildSectionHeader('Description & Details'),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                border: const OutlineInputBorder(),
                                errorText: _fieldErrors['description'],
                                helperText: 'Product description (optional)',
                              ),
                              validator: (value) {
                                if (value != null && value.length > 1000) {
                                  return 'Description must not exceed 1000 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Specifications
                            TextFormField(
                              controller: _specificationsController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Technical Specifications',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter technical specifications (JSON format supported)',
                                helperText:
                                    'Technical specifications (optional)',
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Physical Properties Section
                            _buildSectionHeader('Physical Properties'),
                            const SizedBox(height: 16),

                            // Weight, Dimensions, Material Row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d*'),
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Weight (kg)',
                                      border: const OutlineInputBorder(),
                                      errorText: _fieldErrors['weight'],
                                      helperText: 'Product weight',
                                    ),
                                    validator: (value) {
                                      if (value != null &&
                                          value.trim().isNotEmpty) {
                                        final weight = double.tryParse(
                                          value.trim(),
                                        );
                                        if (weight == null) {
                                          return 'Invalid weight format';
                                        }
                                        if (weight < 0) {
                                          return 'Weight cannot be negative';
                                        }
                                        if (weight > 1000) {
                                          return 'Weight cannot exceed 1000 kg';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _dimensionsController,
                                    decoration: const InputDecoration(
                                      labelText: 'Dimensions',
                                      border: OutlineInputBorder(),
                                      hintText: 'L x W x H (cm)',
                                      helperText: 'Product dimensions',
                                    ),
                                    validator: (value) {
                                      if (value != null && value.length > 100) {
                                        return 'Dimensions must not exceed 100 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _materialController,
                                    decoration: const InputDecoration(
                                      labelText: 'Material',
                                      border: OutlineInputBorder(),
                                      hintText: 'e.g., Steel, Plastic',
                                      helperText: 'Material type',
                                    ),
                                    validator: (value) {
                                      if (value != null && value.length > 100) {
                                        return 'Material must not exceed 100 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Additional Properties Section
                            _buildSectionHeader('Additional Properties'),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                // Warranty
                                SizedBox(
                                  width: 200,
                                  child: TextFormField(
                                    controller: _warrantyController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Warranty (months)',
                                      border: const OutlineInputBorder(),
                                      errorText:
                                          _fieldErrors['warranty_months'],
                                      helperText: 'Warranty period',
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Warranty is required';
                                      }
                                      final warranty = int.tryParse(
                                        value.trim(),
                                      );
                                      if (warranty == null) {
                                        return 'Invalid warranty format';
                                      }
                                      if (warranty < 0) {
                                        return 'Warranty cannot be negative';
                                      }
                                      if (warranty > 120) {
                                        return 'Warranty cannot exceed 120 months';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Checkboxes
                                Expanded(
                                  child: Column(
                                    children: [
                                      CheckboxListTile(
                                        title: const Text('Universal Fit'),
                                        subtitle: const Text(
                                          'Fits all vehicle models',
                                        ),
                                        value: _isUniversal,
                                        onChanged: (value) {
                                          setState(() {
                                            _isUniversal = value ?? false;
                                          });
                                        },
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                      CheckboxListTile(
                                        title: const Text('Active'),
                                        subtitle: const Text(
                                          'Product is available for sale',
                                        ),
                                        value: _isActive,
                                        onChanged: (value) {
                                          setState(() {
                                            _isActive = value ?? true;
                                          });
                                        },
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Vehicle Compatibility Section
                            if (!_isUniversal) ...[
                              _buildSectionHeader('Vehicle Compatibility'),
                              const SizedBox(height: 16),
                              _buildVehicleCompatibilitySection(),
                              const SizedBox(height: 24),
                            ],

                            // Product Images Section
                            _buildSectionHeader('Product Images'),
                            const SizedBox(height: 16),
                            _buildImageSection(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Update Product'
                                    : 'Create Product',
                              ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Add Images'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            if (_selectedImagePaths.isNotEmpty)
              Text(
                '${_selectedImagePaths.length} image(s) selected',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedImagePaths.isNotEmpty) ...[
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              itemCount: _selectedImagePaths.length,
              itemBuilder: (context, index) {
                return _buildImageCard(index);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap on an image to set it as primary. Primary image will be shown first.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ] else ...[
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No images selected',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageCard(int index) {
    final imagePath = _selectedImagePaths[index];
    final isPrimary = _primaryImageIndex == index;

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isPrimary ? Colors.blue : Colors.grey.shade300,
          width: isPrimary ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _setPrimaryImage(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: _buildImageWidget(imagePath),
            ),
          ),
          if (isPrimary)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PRIMARY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String imagePath) {
    final imageFile = File(imagePath);
    return FutureBuilder<bool>(
      future: imageFile.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: 140,
            height: 180,
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return Image.file(
            imageFile,
            width: 140,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading image in form: $imagePath - $error');
              return _buildImagePlaceholder();
            },
          );
        } else {
          debugPrint('Image file does not exist in form: $imagePath');
          return _buildImagePlaceholder();
        }
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 140,
      height: 180,
      color: Colors.grey.shade200,
      child: Icon(Icons.broken_image, color: Colors.grey.shade400, size: 40),
    );
  }

  Widget _buildVehicleCompatibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        TextField(
          controller: _vehicleSearchController,
          decoration: const InputDecoration(
            labelText: 'Search Vehicles',
            hintText:
                'Search by manufacturer, model, year, type, or capacity...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: _filterVehicles,
        ),
        const SizedBox(height: 16),

        // Selected vehicles count
        if (_selectedVehicleIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_selectedVehicleIds.length} vehicle(s) selected',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Vehicle list
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _filteredVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No vehicles found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (_vehicleSearchController.text.isNotEmpty)
                        Text(
                          'Try adjusting your search terms',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _filteredVehicles[index];
                    final isSelected = _selectedVehicleIds.contains(vehicle.id);

                    return CheckboxListTile(
                      title: Text(
                        '${vehicle.manufacturerName ?? 'Unknown'} ${vehicle.name}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vehicle.vehicleTypeName != null)
                            Text('Type: ${vehicle.vehicleTypeName}'),
                          Row(
                            children: [
                              if (vehicle.modelYear != null)
                                Text('Year: ${vehicle.modelYear}'),
                              if (vehicle.modelYear != null &&
                                  vehicle.engineCapacity != null)
                                const Text(' • '),
                              if (vehicle.engineCapacity != null)
                                Text('Engine: ${vehicle.engineCapacity}'),
                            ],
                          ),
                        ],
                      ),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleVehicleCompatibility(
                          vehicle.id!,
                          value ?? false,
                        );
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}
