using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPassengerPickupDropToRideBookings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PassengerDropAddress",
                table: "RideBookings",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<double>(
                name: "PassengerDropLatitude",
                table: "RideBookings",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "PassengerDropLongitude",
                table: "RideBookings",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<string>(
                name: "PassengerDropName",
                table: "RideBookings",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "PassengerPickupAddress",
                table: "RideBookings",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<double>(
                name: "PassengerPickupLatitude",
                table: "RideBookings",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<double>(
                name: "PassengerPickupLongitude",
                table: "RideBookings",
                type: "float",
                nullable: false,
                defaultValue: 0.0);

            migrationBuilder.AddColumn<string>(
                name: "PassengerPickupName",
                table: "RideBookings",
                type: "nvarchar(300)",
                maxLength: 300,
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PassengerDropAddress",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerDropLatitude",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerDropLongitude",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerDropName",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerPickupAddress",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerPickupLatitude",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerPickupLongitude",
                table: "RideBookings");

            migrationBuilder.DropColumn(
                name: "PassengerPickupName",
                table: "RideBookings");
        }
    }
}
