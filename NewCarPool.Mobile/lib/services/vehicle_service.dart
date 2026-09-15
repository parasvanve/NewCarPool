// import '../core/network/api_client.dart';
// import '../models/vehicle_models.dart';

// class VehicleService {
//   VehicleService(this._apiClient);

//   final ApiClient _apiClient;

//   Future<List<Vehicle>> getMine() async {
//     final response = await _apiClient.dio.get('/vehicles/mine');
//     final items = response.data as List<dynamic>;
//     return items.map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item))).toList();
//   }

//   Future<Vehicle> add(UpsertVehicleInput input) async {
//     final response = await _apiClient.dio.post('/vehicles', data: input.toJson());
//     return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
//   }

//   Future<Vehicle> update(String vehicleId, UpsertVehicleInput input) async {
//     final response = await _apiClient.dio.put('/vehicles/$vehicleId', data: input.toJson());
//     return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
//   }

//   Future<void> delete(String vehicleId) async {
//     await _apiClient.dio.delete('/vehicles/$vehicleId');
//   }
// }

//new code
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/vehicle_models.dart';

/// A picked image, kept platform-agnostic: on mobile/desktop it carries a
/// [path], on web it carries raw [bytes] (path is unavailable in the browser).
class VehicleImageFile {
  const VehicleImageFile({
    required this.fileName,
    required this.contentType,
    this.path,
    this.bytes,
  });

  final String fileName;
  final String contentType;
  final String? path;
  final Uint8List? bytes;
}

class VehicleService {
  VehicleService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Vehicle>> getMine() async {
    final response = await _apiClient.dio.get('/vehicles/mine');
    final items = response.data as List<dynamic>;
    return items
        .map((item) => Vehicle.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Vehicle> add(UpsertVehicleInput input) async {
    final response =
        await _apiClient.dio.post('/vehicles', data: input.toJson());
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<Vehicle> update(String vehicleId, UpsertVehicleInput input) async {
    final response =
        await _apiClient.dio.put('/vehicles/$vehicleId', data: input.toJson());
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> delete(String vehicleId) async {
    await _apiClient.dio.delete('/vehicles/$vehicleId');
  }

  Future<Vehicle> uploadRcImage(String vehicleId, VehicleImageFile file) =>
      _uploadImage('/vehicles/$vehicleId/rc-image', file);

  Future<Vehicle> uploadVehicleImage(String vehicleId, VehicleImageFile file) =>
      _uploadImage('/vehicles/$vehicleId/vehicle-image', file);

  Future<Vehicle> _uploadImage(String path, VehicleImageFile file) async {
    if (kIsWeb && (file.bytes == null || file.bytes!.isEmpty)) {
      throw ArgumentError('Selected image could not be read in this browser.');
    }

    final multipartFile = !kIsWeb && file.path != null
        ? await MultipartFile.fromFile(
            file.path!,
            filename: file.fileName,
            contentType: DioMediaType.parse(file.contentType),
          )
        : MultipartFile.fromBytes(
            file.bytes ?? Uint8List(0),
            filename: file.fileName,
            contentType: DioMediaType.parse(file.contentType),
          );

    final formData = FormData.fromMap({'file': multipartFile});
    final response = await _apiClient.dio.post(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data));
  }
}
