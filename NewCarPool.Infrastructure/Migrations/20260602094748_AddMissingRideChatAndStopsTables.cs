using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddMissingRideChatAndStopsTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RideChatGroups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RideOfferId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RideChatGroups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RideChatGroups_RideOffers_RideOfferId",
                        column: x => x.RideOfferId,
                        principalTable: "RideOffers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RideChatMessages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RideChatGroupId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SenderUserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Message = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RideChatMessages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RideChatMessages_RideChatGroups_RideChatGroupId",
                        column: x => x.RideChatGroupId,
                        principalTable: "RideChatGroups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RideChatMessages_Users_SenderUserId",
                        column: x => x.SenderUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "RideStops",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    RideOfferId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Address = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Latitude = table.Column<double>(type: "float", nullable: false),
                    Longitude = table.Column<double>(type: "float", nullable: false),
                    StopOrder = table.Column<int>(type: "int", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RideStops", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RideStops_RideOffers_RideOfferId",
                        column: x => x.RideOfferId,
                        principalTable: "RideOffers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RideChatGroups_RideOfferId",
                table: "RideChatGroups",
                column: "RideOfferId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RideChatMessages_SenderUserId",
                table: "RideChatMessages",
                column: "SenderUserId");

            migrationBuilder.CreateIndex(
                name: "IX_RideChatMessages_RideChatGroupId_CreatedAtUtc",
                table: "RideChatMessages",
                columns: new[] { "RideChatGroupId", "CreatedAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_RideStops_RideOfferId_StopOrder",
                table: "RideStops",
                columns: new[] { "RideOfferId", "StopOrder" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RideChatMessages");

            migrationBuilder.DropTable(
                name: "RideChatGroups");

            migrationBuilder.DropTable(
                name: "RideStops");
        }
    }
}
