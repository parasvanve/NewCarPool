class RideShareResponse {
  final String driverName;
  final String origin;
  final String destination;
  final String departureTime;
  final int availableSeats;
  final double pricePerSeat;
  final String shareUrl;

  RideShareResponse({
    required this.driverName,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.availableSeats,
    required this.pricePerSeat,
    required this.shareUrl,
  });

  factory RideShareResponse.fromJson(Map<String, dynamic> json) {
    return RideShareResponse(
      driverName: json['driverName'],
      origin: json['origin'],
      destination: json['destination'],
      departureTime: json['departureTime'],
      availableSeats: json['availableSeats'],
      pricePerSeat: (json['pricePerSeat'] as num).toDouble(),
      shareUrl: json['shareUrl'],
    );
  }
}
