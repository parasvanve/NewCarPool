using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    public partial class EnsureRideChatTablesExist : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF OBJECT_ID('RideChatGroups', 'U') IS NULL
                BEGIN
                    CREATE TABLE RideChatGroups (
                        Id uniqueidentifier NOT NULL PRIMARY KEY,
                        RideOfferId uniqueidentifier NOT NULL,
                        CreatedAtUtc datetime2 NOT NULL,
                        CONSTRAINT FK_RideChatGroups_RideOffers_RideOfferId FOREIGN KEY (RideOfferId) REFERENCES RideOffers(Id) ON DELETE CASCADE
                    );
                    CREATE UNIQUE INDEX IX_RideChatGroups_RideOfferId ON RideChatGroups(RideOfferId);
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID('RideChatMessages', 'U') IS NULL
                BEGIN
                    CREATE TABLE RideChatMessages (
                        Id uniqueidentifier NOT NULL PRIMARY KEY,
                        RideChatGroupId uniqueidentifier NOT NULL,
                        SenderUserId uniqueidentifier NOT NULL,
                        Message nvarchar(2000) NOT NULL,
                        CreatedAtUtc datetime2 NOT NULL,
                        CONSTRAINT FK_RideChatMessages_RideChatGroups_RideChatGroupId FOREIGN KEY (RideChatGroupId) REFERENCES RideChatGroups(Id) ON DELETE CASCADE,
                        CONSTRAINT FK_RideChatMessages_Users_SenderUserId FOREIGN KEY (SenderUserId) REFERENCES Users(Id) ON DELETE NO ACTION
                    );
                    CREATE INDEX IX_RideChatMessages_RideChatGroupId_CreatedAtUtc ON RideChatMessages(RideChatGroupId, CreatedAtUtc);
                    CREATE INDEX IX_RideChatMessages_SenderUserId ON RideChatMessages(SenderUserId);
                END
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF OBJECT_ID('RideChatMessages', 'U') IS NOT NULL DROP TABLE RideChatMessages;");
            migrationBuilder.Sql("IF OBJECT_ID('RideChatGroups', 'U') IS NOT NULL DROP TABLE RideChatGroups;");
        }
    }
}
