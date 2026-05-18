enum VehicleType {
  hatchback(1, 'Hatchback'),
  sedan(2, 'Sedan'),
  suv(3, 'SUV'),
  bike(4, 'Bike'),
  van(5, 'Van');

  const VehicleType(this.value, this.label);

  final int value;
  final String label;

  static VehicleType fromValue(int value) =>
      VehicleType.values.firstWhere((type) => type.value == value, orElse: () => VehicleType.sedan);
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.vehicleName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.color,
    required this.seats,
    required this.isVerified,
    this.rcImagePath,
    this.vehicleImagePath,
  });

  final String id;
  final String vehicleName;
  final String vehicleNumber;
  final VehicleType vehicleType;
  final String color;
  final int seats;
  final String? rcImagePath;
  final String? vehicleImagePath;
  final bool isVerified;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'],
        vehicleName: json['vehicleName'],
        vehicleNumber: json['vehicleNumber'],
        vehicleType: VehicleType.fromValue(json['vehicleType']),
        color: json['color'],
        seats: json['seats'],
        rcImagePath: json['rcImagePath'],
        vehicleImagePath: json['vehicleImagePath'],
        isVerified: json['isVerified'] ?? false,
      );
}

class UpsertVehicleInput {
  const UpsertVehicleInput({
    required this.vehicleName,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.color,
    required this.seats,
    this.rcImagePath,
    this.vehicleImagePath,
  });

  final String vehicleName;
  final String vehicleNumber;
  final VehicleType vehicleType;
  final String color;
  final int seats;
  final String? rcImagePath;
  final String? vehicleImagePath;

  Map<String, dynamic> toJson() => {
        'vehicleName': vehicleName,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType.value,
        'color': color,
        'seats': seats,
        'rcImagePath': rcImagePath,
        'vehicleImagePath': vehicleImagePath,
      };
}
