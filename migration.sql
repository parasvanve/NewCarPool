BEGIN TRANSACTION;
GO

ALTER TABLE [RideStops] ADD [ReachedAtUtc] datetime2 NULL;
GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260904102517_AddRideStopReachedAtUtc', N'8.0.15');
GO

COMMIT;
GO

