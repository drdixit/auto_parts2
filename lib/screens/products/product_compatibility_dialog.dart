import 'package:flutter/material.dart';
import 'package:auto_parts2/models/product.dart';
import 'package:auto_parts2/models/product_compatibility.dart';
import 'package:auto_parts2/models/vehicle_model.dart';
import 'package:auto_parts2/services/product_service.dart';

class ProductCompatibilityDialog extends StatefulWidget {
  final Product product;

  const ProductCompatibilityDialog({super.key, required this.product});

  @override
  State<ProductCompatibilityDialog> createState() =>
      _ProductCompatibilityDialogState();
}

class _ProductCompatibilityDialogState
    extends State<ProductCompatibilityDialog> {
  final ProductService _productService = ProductService();
  List<ProductCompatibility> _compatibilities = [];
  List<VehicleModel> _allVehicles = [];
  List<VehicleModel> _filteredVehicles = [];
  Set<int> _selectedVehicleIds = {};
  final TextEditingController _vehicleSearchController =
      TextEditingController();
  bool _isLoading = true;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _vehicleSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final compatibilities = await _productService.getProductCompatibility(
        widget.product.id!,
      );
      final vehicles = await _productService.getAllVehicleModels();

      setState(() {
        _compatibilities = compatibilities;
        _allVehicles = vehicles;
        _filteredVehicles = vehicles;
        _selectedVehicleIds = compatibilities
            .map((c) => c.vehicleModelId)
            .toSet();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
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

  Future<void> _toggleVehicleCompatibility(int vehicleId, bool selected) async {
    setState(() {
      _isAddingNew = true;
    });

    try {
      if (selected) {
        // Add compatibility
        final compatibility = ProductCompatibility(
          productId: widget.product.id!,
          vehicleModelId: vehicleId,
          fitNotes: 'Direct fit',
          compatibilityConfirmed: true,
          addedBy: 'System',
        );

        final result = await _productService.addProductCompatibility(
          compatibility,
        );

        if (result['success']) {
          if (!mounted) return;
          setState(() {
            _selectedVehicleIds.add(vehicleId);
          });
          await _loadData(); // Refresh to get the new compatibility with ID
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to add compatibility'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Remove compatibility
        final compatibilityToRemove = _compatibilities.firstWhere(
          (c) => c.vehicleModelId == vehicleId,
        );

        if (compatibilityToRemove.id != null) {
          final result = await _productService.removeProductCompatibility(
            compatibilityToRemove.id!,
          );

          if (result['success']) {
            if (!mounted) return;
            setState(() {
              _selectedVehicleIds.remove(vehicleId);
            });
            await _loadData(); // Refresh the list
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result['error'] ?? 'Failed to remove compatibility',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isAddingNew = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Compatibility',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.product.name,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                    Icon(
                      Icons.check_circle,
                      color: Colors.blue.shade600,
                      size: 16,
                    ),
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
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
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
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
                                final isSelected = _selectedVehicleIds.contains(
                                  vehicle.id,
                                );

                                return CheckboxListTile(
                                  title: Text(
                                    '${vehicle.manufacturerName ?? 'Unknown'} ${vehicle.name}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (vehicle.vehicleTypeName != null)
                                        Text(
                                          'Type: ${vehicle.vehicleTypeName}',
                                        ),
                                      Row(
                                        children: [
                                          if (vehicle.modelYear != null)
                                            Text('Year: ${vehicle.modelYear}'),
                                          if (vehicle.modelYear != null &&
                                              vehicle.engineCapacity != null)
                                            const Text(' • '),
                                          if (vehicle.engineCapacity != null)
                                            Text(
                                              'Engine: ${vehicle.engineCapacity}',
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  value: isSelected,
                                  onChanged: _isAddingNew
                                      ? null
                                      : (bool? value) {
                                          _toggleVehicleCompatibility(
                                            vehicle.id!,
                                            value ?? false,
                                          );
                                        },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  dense: true,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
