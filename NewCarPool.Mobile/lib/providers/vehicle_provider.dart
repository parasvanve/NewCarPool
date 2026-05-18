import 'package:flutter/foundation.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';

class VehicleProvider extends ChangeNotifier {
  VehicleProvider(this._vehicleService);

  final VehicleService _vehicleService;
  final List<Vehicle> vehicles = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> loadMine() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _vehicleService.getMine();
      vehicles
        ..clear()
        ..addAll(result);
    } catch (error) {
      errorMessage = error.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add(UpsertVehicleInput input) async {
    final vehicle = await _vehicleService.add(input);
    vehicles.insert(0, vehicle);
    notifyListeners();
  }

  Future<void> update(String vehicleId, UpsertVehicleInput input) async {
    final vehicle = await _vehicleService.update(vehicleId, input);
    final index = vehicles.indexWhere((item) => item.id == vehicleId);
    if (index >= 0) {
      vehicles[index] = vehicle;
    }
    notifyListeners();
  }

  Future<void> delete(String vehicleId) async {
    await _vehicleService.delete(vehicleId);
    vehicles.removeWhere((item) => item.id == vehicleId);
    notifyListeners();
  }
}
