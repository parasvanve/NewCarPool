using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddRideLastKnownDriverLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "LastDriverHeading",
                table: "RideOffers",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastDriverLatitude",
                table: "RideOffers",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LastDriverLocationAtUtc",
                table: "RideOffers",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastDriverLongitude",
                table: "RideOffers",
                type: "float",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastDriverSpeedKph",
                table: "RideOffers",
                type: "float",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_RideOffers_Id_LastDriverLocationAtUtc",
                table: "RideOffers",
                columns: new[] { "Id", "LastDriverLocationAtUtc" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_RideOffers_Id_LastDriverLocationAtUtc",
                table: "RideOffers");

            migrationBuilder.DropColumn(
                name: "LastDriverHeading",
                table: "RideOffers");

            migrationBuilder.DropColumn(
                name: "LastDriverLatitude",
                table: "RideOffers");

            migrationBuilder.DropColumn(
                name: "LastDriverLocationAtUtc",
                table: "RideOffers");

            migrationBuilder.DropColumn(
                name: "LastDriverLongitude",
                table: "RideOffers");

            migrationBuilder.DropColumn(
                name: "LastDriverSpeedKph",
                table: "RideOffers");
        }
    }
}
