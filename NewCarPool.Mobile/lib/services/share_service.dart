import 'package:share_plus/share_plus.dart';

import '../models/ride_share_response.dart';

class ShareService {
  const ShareService._();

  static Future<void> shareRide(RideShareResponse ride) async {
    final message = '''
🚗 Join My CarPool Ride!

👤 Driver: ${ride.driverName}

📍 From: ${ride.origin}

📍 To: ${ride.destination}

🕒 Departure: ${ride.departureTime}

💺 Available Seats: ${ride.availableSeats}

💰 Fare per Seat: ₹${ride.pricePerSeat.toStringAsFixed(0)}

🔗 Join this ride:
${ride.shareUrl}

Download NewCarPool and book your seat now!
''';

    await Share.share(
      message,
      subject: 'Join My CarPool Ride',
    );
  }
}
