import 'package:auto_parts2/database/database_helper.dart';
import 'package:auto_parts2/models/vehicle_model.dart';
import 'package:auto_parts2/models/vehicle_type.dart';
import 'package:auto_parts2/models/manufacturer.dart';

class VehicleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<VehicleModel>> getAllVehicleModels({
    bool includeInactive = false,
  }) async {
    final db = await _dbHelper.database;
    final String query =
        '''
      SELECT
        vm.*,
        m.name as manufacturer_name,
        vt.name as vehicle_type_name
      FROM vehicle_models vm
      JOIN manufacturers m ON vm.manufacturer_id = m.id
      JOIN vehicle_types vt ON vm.vehicle_type_id = vt.id
      ${includeInactive ? '' : 'WHERE vm.is_active = 1'}
      ORDER BY m.name ASC, vm.model_year DESC, vm.name ASC
    ''';

    final results = await db.rawQuery(query);
    return results.map((map) => VehicleModel.fromMap(map)).toList();
  }

  Future<VehicleModel?> getVehicleModelById(int id) async {
    final maps = await _dbHelper.getRecords(
      'vehicle_models',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return VehicleModel.fromMap(maps.first);
    return null;
  }

  Future<int> insertVehicleModel(VehicleModel model) async {
    final data = model.toMap();
    data.remove('id');
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    return await _dbHelper.insertRecord('vehicle_models', data);
  }

  Future<int> updateVehicleModel(VehicleModel model) async {
    if (model.id == null)
      throw ArgumentError('VehicleModel id required for update');
    final data = model.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    data.remove('id');
    return await _dbHelper.updateRecord('vehicle_models', data, 'id = ?', [
      model.id,
    ]);
  }

  Future<int> softDeleteVehicleModel(int id) async {
    return await _dbHelper.softDeleteRecord('vehicle_models', id);
  }

  Future<List<VehicleType>> getVehicleTypes() async {
    final maps = await _dbHelper.getRecords('vehicle_types');
    return maps.map((m) => VehicleType.fromMap(m)).toList();
  }

  Future<List<Manufacturer>> getManufacturers() async {
    final maps = await _dbHelper.getRecords('manufacturers');
    return maps.map((m) => Manufacturer.fromMap(m)).toList();
  }
}
