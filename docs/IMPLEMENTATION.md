# NewCarPool Implementation Guide

## Architecture

The backend follows:

`Controllers -> Services -> Repositories -> EF Core -> SQL Server`

Projects:

- `NewCarPool.Domain`: entities and enums only.
- `NewCarPool.Application`: DTOs, service interfaces, repository interfaces, shared exceptions.
- `NewCarPool.Infrastructure`: EF Core, repositories, service implementations, JWT, SQL Server.
- `NewCarPool.Api`: controllers, Swagger, SignalR hub, middleware.
- `NewCarPool.Mobile`: Flutter app using Provider, Dio, Flutter Map, and SignalR.

## User Role Logic

There is no permanent driver/passenger role table.

- A user becomes a driver for a ride when they create `RideOffer`.
- A user becomes a passenger for a ride when they create `RideBooking`.
- The same user can offer one ride and book another ride at any time.
- The service layer blocks a driver from booking their own ride.

## Backend Setup

1. Update `NewCarPool.Api/appsettings.json`.
2. Replace the JWT signing key with a long secret from environment/configuration.
3. Set `ConnectionStrings:DefaultConnection` to SQL Server.
4. Restore packages:

```powershell
dotnet restore .\NewCarPool.slnx
```

5. Create migrations:

```powershell
dotnet ef migrations add InitialCreate --project .\NewCarPool.Infrastructure --startup-project .\NewCarPool.Api
dotnet ef database update --project .\NewCarPool.Infrastructure --startup-project .\NewCarPool.Api
```

6. Run the API:

```powershell
dotnet run --project .\NewCarPool.Api
```

Swagger is available at `/swagger` in development.

## Main APIs

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`
- `GET /api/profile`
- `PUT /api/profile`
- `POST /api/profile/image`
- `GET /api/vehicles/mine`
- `POST /api/vehicles`
- `PUT /api/vehicles/{vehicleId}`
- `DELETE /api/vehicles/{vehicleId}`
- `POST /api/rides/offer`
- `GET /api/rides/search`
- `GET /api/rides/{rideOfferId}`
- `PUT /api/rides/{rideOfferId}`
- `DELETE /api/rides/{rideOfferId}`
- `POST /api/rides/book`
- `POST /api/rides/{rideOfferId}/start`
- `POST /api/rides/{rideOfferId}/complete`
- `POST /api/rides/{rideOfferId}/cancel`
- `POST /api/bookings/{bookingId}/accept`
- `POST /api/bookings/{bookingId}/reject`
- `POST /api/bookings/{bookingId}/cancel`
- `GET /api/bookings/history`
- `POST /api/payments`
- `POST /api/payments/verify`
- `GET /api/payments/history`
- `GET /api/notifications`
- `POST /api/notifications`
- `POST /api/notifications/{notificationId}/read`
- `POST /api/reviews`
- `GET /api/reviews/user/{userId}`
- `GET /api/reviews/user/{userId}/average`
- `POST /api/tracking/location`
- `POST /api/maps/route`
- `GET /api/maps/geocode`
- `GET /api/admin/dashboard`
- SignalR hub: `/hubs/tracking`
- SignalR hub: `/hubs/notifications`

## Maps

The Flutter app uses OpenStreetMap tiles through `flutter_map`.

Recommended production additions:

- Use OpenRouteService to calculate actual route geometry and persist encoded polyline in `RideOffer.RoutePolyline`.
- Use Nominatim for search/autocomplete with a clear user agent and usage policy compliance.
- Cache route and geocode responses server-side to avoid rate-limit pressure.

If `ExternalApis:OpenRouteServiceApiKey` is empty, the backend returns a Haversine distance and estimated ETA fallback so local development keeps working.

## Mobile Setup

1. Open `NewCarPool.Mobile`.
2. Run:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:5001
```

For a physical phone, replace `10.0.2.2` with the API host reachable from the device.

## Production Checklist

- Move JWT key and OpenRouteService API key into secrets or environment variables.
- Add FluentValidation or endpoint filters for deeper request validation.
- Add EF migrations to source control.
- Add rate limiting for auth and map proxy endpoints.
- Add background cleanup for expired refresh tokens.
- Add logging sinks such as Application Insights, Seq, or ELK.
- Add integration tests for auth, booking concurrency, and tracking authorization.
- Replace demo token return from forgot-password with email/SMS delivery.
- Wire a real payment gateway verification webhook before production launch.
