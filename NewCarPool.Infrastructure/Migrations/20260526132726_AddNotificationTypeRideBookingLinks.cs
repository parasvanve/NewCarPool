using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddNotificationTypeRideBookingLinks : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "BookingId",
                table: "Notifications",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "RideId",
                table: "Notifications",
                type: "uniqueidentifier",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Type",
                table: "Notifications",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BookingId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "RideId",
                table: "Notifications");

            migrationBuilder.DropColumn(
                name: "Type",
                table: "Notifications");
        }
    }
}
