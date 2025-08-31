import 'package:flutter/material.dart';
import 'package:auto_parts2/theme/app_colors.dart';
import 'package:auto_parts2/services/vehicle_service.dart';
import 'package:auto_parts2/models/vehicle_model.dart';
import 'vehicle_form_dialog.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _VehiclesScreenBody();
  }
}

class _VehiclesScreenBody extends StatefulWidget {
  @override
  State<_VehiclesScreenBody> createState() => _VehiclesScreenBodyState();
}

class _VehiclesScreenBodyState extends State<_VehiclesScreenBody> {
  final VehicleService _service = VehicleService();
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    _vehicles = await _service.getAllVehicleModels();
    setState(() => _isLoading = false);
  }

  void _showAdd() async {
    final types = await _service.getVehicleTypes();
    final manufacturers = await _service.getManufacturers();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => VehicleFormDialog(
        types: types,
        manufacturers: manufacturers,
        onSubmit: (model) async {
          await _service.insertVehicleModel(model);
          if (mounted) await _load();
        },
      ),
    );
  }

  void _showEdit(VehicleModel model) async {
    final types = await _service.getVehicleTypes();
    final manufacturers = await _service.getManufacturers();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => VehicleFormDialog(
        model: model,
        types: types,
        manufacturers: manufacturers,
        onSubmit: (m) async {
          await _service.updateVehicleModel(m);
          if (mounted) await _load();
        },
      ),
    );
  }

  Future<void> _softDelete(int id) async {
    await _service.softDeleteVehicleModel(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Vehicles',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Vehicle'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _vehicles.isEmpty
                ? Center(
                    child: Text(
                      'No vehicles found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _vehicles.length,
                    itemBuilder: (context, i) {
                      final v = _vehicles[i];
                      return Card(
                        child: ListTile(
                          title: Text(v.displayName),
                          subtitle: Text(
                            '${v.manufacturerName ?? ''} • ${v.vehicleTypeName ?? ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () => _showEdit(v),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => _softDelete(v.id!),
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
}
