import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/product_compatibility.dart';
import '../../models/vehicle_model.dart';
import '../../services/product_service.dart';

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
  bool _isLoading = true;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _showAddCompatibilityDialog() async {
    // Get vehicles not already compatible
    final compatibleVehicleIds = _compatibilities
        .map((c) => c.vehicleModelId)
        .toSet();
    final availableVehicles = _allVehicles
        .where((v) => !compatibleVehicleIds.contains(v.id))
        .toList();

    if (availableVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All available vehicles are already compatible with this product',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await showDialog<VehicleModel>(
      context: context,
      builder: (context) =>
          _AddCompatibilityDialog(vehicles: availableVehicles),
    );

    if (result != null) {
      await _addCompatibility(result);
    }
  }

  Future<void> _addCompatibility(VehicleModel vehicle) async {
    setState(() {
      _isAddingNew = true;
    });

    try {
      final compatibility = ProductCompatibility(
        productId: widget.product.id!,
        vehicleModelId: vehicle.id!,
        fitNotes: 'Direct fit',
        compatibilityConfirmed: true,
        addedBy: 'System',
      );

      final result = await _productService.addProductCompatibility(
        compatibility,
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to add compatibility'),
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
    } finally {
      setState(() {
        _isAddingNew = false;
      });
    }
  }

  Future<void> _removeCompatibility(ProductCompatibility compatibility) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Compatibility'),
        content: Text(
          'Remove compatibility with ${compatibility.vehicleDisplayName}?',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _productService.removeProductCompatibility(
          compatibility.id!,
        );

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ?? 'Failed to remove compatibility',
              ),
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

            // Add button
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading || _isAddingNew
                      ? null
                      : _showAddCompatibilityDialog,
                  icon: _isAddingNew
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add Vehicle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_compatibilities.length} compatible vehicles',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Compatibility list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _compatibilities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_car_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            // TODO: Universal fit feature - disabled for future implementation
                            // widget.product.isUniversal
                            //     ? 'This is a universal part that fits all vehicles'
                            //     : 'No vehicle compatibility defined',
                            'No vehicle compatibility defined',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _compatibilities.length,
                      itemBuilder: (context, index) {
                        final compatibility = _compatibilities[index];
                        return _buildCompatibilityCard(compatibility);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityCard(ProductCompatibility compatibility) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: compatibility.isOem
              ? Colors.orange[100]
              : Colors.blue[100],
          child: Icon(
            compatibility.isOem ? Icons.verified : Icons.directions_car,
            color: compatibility.isOem ? Colors.orange[800] : Colors.blue[800],
            size: 20,
          ),
        ),
        title: Text(
          compatibility.vehicleDisplayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${compatibility.vehicleTypeName}'),
            if (compatibility.fitNotes != null)
              Text('Fit: ${compatibility.fitNotes}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (compatibility.isOem)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'OEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeCompatibility(compatibility),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Remove compatibility',
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCompatibilityDialog extends StatefulWidget {
  final List<VehicleModel> vehicles;

  const _AddCompatibilityDialog({required this.vehicles});

  @override
  State<_AddCompatibilityDialog> createState() =>
      _AddCompatibilityDialogState();
}

class _AddCompatibilityDialogState extends State<_AddCompatibilityDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<VehicleModel> _filteredVehicles = [];

  @override
  void initState() {
    super.initState();
    _filteredVehicles = widget.vehicles;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVehicles(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredVehicles = widget.vehicles;
      } else {
        _filteredVehicles = widget.vehicles.where((vehicle) {
          return vehicle.name.toLowerCase().contains(query.toLowerCase()) ||
              (vehicle.manufacturerName?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false) ||
              (vehicle.vehicleTypeName?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false) ||
              (vehicle.engineCapacity?.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ??
                  false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Vehicle Compatibility'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search vehicles...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterVehicles,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _filteredVehicles[index];
                  return ListTile(
                    title: Text(vehicle.displayName),
                    subtitle: Text(
                      '${vehicle.manufacturerName} • ${vehicle.vehicleTypeName}',
                    ),
                    onTap: () => Navigator.of(context).pop(vehicle),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
