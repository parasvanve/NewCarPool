USE NewCarPoolDb;
GO

DECLARE @AdminId UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @DriverId UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';
DECLARE @VehicleId UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';

INSERT INTO Users (Id, FullName, Email, PhoneNumber, PasswordHash, IsAdmin)
VALUES
(@AdminId, 'Admin User', 'admin@newcarpool.local', '9999999999', 'REPLACE_WITH_BCRYPT_HASH', 1),
(@DriverId, 'Demo Driver', 'driver@newcarpool.local', '8888888888', 'REPLACE_WITH_BCRYPT_HASH', 0);

INSERT INTO Vehicles (Id, OwnerId, VehicleName, VehicleNumber, VehicleType, Color, Seats, IsVerified)
VALUES (@VehicleId, @DriverId, 'Demo Sedan', 'KA 01 AB 1234', 2, 'White', 4, 1);
