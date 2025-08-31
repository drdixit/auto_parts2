import 'package:flutter/material.dart';
import 'package:auto_parts2/models/vehicle_model.dart';
import 'package:auto_parts2/models/vehicle_type.dart';
import 'package:auto_parts2/models/manufacturer.dart';

class VehicleFormDialog extends StatefulWidget {
  final VehicleModel? model;
  final List<VehicleType> types;
  final List<Manufacturer> manufacturers;
  final void Function(VehicleModel model) onSubmit;

  const VehicleFormDialog({
    super.key,
    this.model,
    required this.types,
    required this.manufacturers,
    required this.onSubmit,
  });

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  VehicleType? _selectedType;
  Manufacturer? _selectedManufacturer;
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.model?.name ?? '');
    if (widget.model != null) {
      _selectedType = widget.types.firstWhere(
        (t) => t.id == widget.model!.vehicleTypeId,
        orElse: () => widget.types.isNotEmpty
            ? widget.types.first
            : VehicleType(name: 'Unknown'),
      );
      _selectedManufacturer = widget.manufacturers.firstWhere(
        (m) => m.id == widget.model!.manufacturerId,
        orElse: () => widget.manufacturers.isNotEmpty
            ? widget.manufacturers.first
            : Manufacturer(name: 'Unknown'),
      );
      _yearController.text = widget.model!.modelYear?.toString() ?? '';
      _ccController.text = widget.model!.engineCapacity ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _yearController.dispose();
    _ccController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final model = VehicleModel(
      id: widget.model?.id,
      name: _nameController.text.trim(),
      manufacturerId: _selectedManufacturer?.id ?? 0,
      vehicleTypeId: _selectedType?.id ?? 0,
      modelYear: _yearController.text.isNotEmpty
          ? int.tryParse(_yearController.text)
          : null,
      engineCapacity: _ccController.text.trim().isNotEmpty
          ? _ccController.text.trim()
          : null,
    );
    widget.onSubmit(model);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.model == null ? 'Add Vehicle Model' : 'Edit Vehicle Model',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Model Name'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name required'
                        : null,
                  ),
                  DropdownButtonFormField<Manufacturer>(
                    initialValue: _selectedManufacturer,
                    items: widget.manufacturers
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text(m.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedManufacturer = v;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Manufacturer',
                    ),
                    validator: (v) => v == null ? 'Select manufacturer' : null,
                  ),
                  DropdownButtonFormField<VehicleType>(
                    initialValue: _selectedType,
                    items: widget.types
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedType = v;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                    ),
                    validator: (v) => v == null ? 'Select vehicle type' : null,
                  ),
                  TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(labelText: 'Model Year'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
