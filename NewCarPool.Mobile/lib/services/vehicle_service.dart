import '../core/network/api_client.dart';
import '../models/vehicle_models.dart';

class VehicleService {
  VehicleService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Vehicle>> getMine() async {
    final response = await _apiClient.dio.get('/vehicles/mine');
    final items = response.data as List<dynamic>;
    return items.map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  Future<Vehicle> add(UpsertVehicleInput input) async {
    final response = await _apiClient.dio.post('/vehicles', data: input.toJson());
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<Vehicle> update(String vehicleId, UpsertVehicleInput input) async {
    final response = await _apiClient.dio.put('/vehicles/$vehicleId', data: input.toJson());
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> delete(String vehicleId) async {
    await _apiClient.dio.delete('/vehicles/$vehicleId');
  }
}
