using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddRideLifecycleSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
IF COL_LENGTH('RideOffers', 'CancellationReason') IS NULL
BEGIN
    ALTER TABLE [RideOffers] ADD [CancellationReason] nvarchar(1000) NULL;
END

IF COL_LENGTH('RideOffers', 'CancelledAtUtc') IS NULL
BEGIN
    ALTER TABLE [RideOffers] ADD [CancelledAtUtc] datetime2 NULL;
END

IF COL_LENGTH('RideOffers', 'CompletedAtUtc') IS NULL
BEGIN
    ALTER TABLE [RideOffers] ADD [CompletedAtUtc] datetime2 NULL;
END

IF COL_LENGTH('RideOffers', 'StartedAtUtc') IS NULL
BEGIN
    ALTER TABLE [RideOffers] ADD [StartedAtUtc] datetime2 NULL;
END
");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
IF COL_LENGTH('RideOffers', 'CancellationReason') IS NOT NULL
BEGIN
    ALTER TABLE [RideOffers] DROP COLUMN [CancellationReason];
END

IF COL_LENGTH('RideOffers', 'CancelledAtUtc') IS NOT NULL
BEGIN
    ALTER TABLE [RideOffers] DROP COLUMN [CancelledAtUtc];
END

IF COL_LENGTH('RideOffers', 'CompletedAtUtc') IS NOT NULL
BEGIN
    ALTER TABLE [RideOffers] DROP COLUMN [CompletedAtUtc];
END

IF COL_LENGTH('RideOffers', 'StartedAtUtc') IS NOT NULL
BEGIN
    ALTER TABLE [RideOffers] DROP COLUMN [StartedAtUtc];
END
");
        }
    }
}