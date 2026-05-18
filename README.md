# NewCarPool

Production-ready starter for a carpool mobile application.

## Stack

- Flutter mobile app
- Provider state management
- Dio API client with JWT refresh handling
- Flutter Map with OpenStreetMap tiles
- SignalR realtime tracking
- Vehicles, bookings, payments, notifications, reviews, maps, and admin modules
- ASP.NET Core Web API on .NET 8
- EF Core and SQL Server
- Repository pattern and service layer
- Swagger and global exception handling

## Folders

- `NewCarPool.Api`
- `NewCarPool.Application`
- `NewCarPool.Domain`
- `NewCarPool.Infrastructure`
- `NewCarPool.Mobile`
- `sql`
- `docs`

See `docs/IMPLEMENTATION.md` for setup and next steps.

Backend build check:

```powershell
dotnet build .\NewCarPool.slnx --no-restore
```

Flutter entry point:

```powershell
cd .\NewCarPool.Mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=https://10.0.2.2:5001
```
