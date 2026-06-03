using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPendingRegistrationOtps : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PendingRegistrationOtps",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                    PhoneNumber = table.Column<string>(type: "nvarchar(30)", maxLength: 30, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    OtpHash = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    ResendAvailableAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    FailedAttempts = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UsedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PendingRegistrationOtps", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PendingRegistrationOtps_Email",
                table: "PendingRegistrationOtps",
                column: "Email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PendingRegistrationOtps_PhoneNumber",
                table: "PendingRegistrationOtps",
                column: "PhoneNumber");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PendingRegistrationOtps");
        }
    }
}
