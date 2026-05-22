using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NewCarPool.Infrastructure.Migrations
{
    public partial class RepairMissingRideChatTables : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                IF OBJECT_ID('dbo.RideChatGroups', 'U') IS NULL
                BEGIN
                    CREATE TABLE [dbo].[RideChatGroups] (
                        [Id] uniqueidentifier NOT NULL,
                        [RideOfferId] uniqueidentifier NOT NULL,
                        [CreatedAtUtc] datetime2 NOT NULL,
                        CONSTRAINT [PK_RideChatGroups] PRIMARY KEY ([Id])
                    );
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID('dbo.RideChatMessages', 'U') IS NULL
                BEGIN
                    CREATE TABLE [dbo].[RideChatMessages] (
                        [Id] uniqueidentifier NOT NULL,
                        [RideChatGroupId] uniqueidentifier NOT NULL,
                        [SenderUserId] uniqueidentifier NOT NULL,
                        [Message] nvarchar(2000) NOT NULL,
                        [CreatedAtUtc] datetime2 NOT NULL,
                        CONSTRAINT [PK_RideChatMessages] PRIMARY KEY ([Id])
                    );
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID('dbo.FK_RideChatGroups_RideOffers_RideOfferId', 'F') IS NULL
                BEGIN
                    ALTER TABLE [dbo].[RideChatGroups]
                    ADD CONSTRAINT [FK_RideChatGroups_RideOffers_RideOfferId]
                    FOREIGN KEY ([RideOfferId]) REFERENCES [dbo].[RideOffers]([Id]) ON DELETE CASCADE;
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID('dbo.FK_RideChatMessages_RideChatGroups_RideChatGroupId', 'F') IS NULL
                BEGIN
                    ALTER TABLE [dbo].[RideChatMessages]
                    ADD CONSTRAINT [FK_RideChatMessages_RideChatGroups_RideChatGroupId]
                    FOREIGN KEY ([RideChatGroupId]) REFERENCES [dbo].[RideChatGroups]([Id]) ON DELETE CASCADE;
                END
                """);

            migrationBuilder.Sql(
                """
                IF OBJECT_ID('dbo.FK_RideChatMessages_Users_SenderUserId', 'F') IS NULL
                BEGIN
                    ALTER TABLE [dbo].[RideChatMessages]
                    ADD CONSTRAINT [FK_RideChatMessages_Users_SenderUserId]
                    FOREIGN KEY ([SenderUserId]) REFERENCES [dbo].[Users]([Id]) ON DELETE NO ACTION;
                END
                """);

            migrationBuilder.Sql(
                """
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RideChatGroups_RideOfferId' AND object_id = OBJECT_ID('dbo.RideChatGroups'))
                BEGIN
                    CREATE UNIQUE INDEX [IX_RideChatGroups_RideOfferId] ON [dbo].[RideChatGroups]([RideOfferId]);
                END
                """);

            migrationBuilder.Sql(
                """
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RideChatMessages_RideChatGroupId_CreatedAtUtc' AND object_id = OBJECT_ID('dbo.RideChatMessages'))
                BEGIN
                    CREATE INDEX [IX_RideChatMessages_RideChatGroupId_CreatedAtUtc] ON [dbo].[RideChatMessages]([RideChatGroupId], [CreatedAtUtc]);
                END
                """);

            migrationBuilder.Sql(
                """
                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RideChatMessages_SenderUserId' AND object_id = OBJECT_ID('dbo.RideChatMessages'))
                BEGIN
                    CREATE INDEX [IX_RideChatMessages_SenderUserId] ON [dbo].[RideChatMessages]([SenderUserId]);
                END
                """);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("IF OBJECT_ID('dbo.RideChatMessages', 'U') IS NOT NULL DROP TABLE [dbo].[RideChatMessages];");
            migrationBuilder.Sql("IF OBJECT_ID('dbo.RideChatGroups', 'U') IS NOT NULL DROP TABLE [dbo].[RideChatGroups];");
        }
    }
}
