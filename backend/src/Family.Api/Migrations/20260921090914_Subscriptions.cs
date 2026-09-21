using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Family.Api.Migrations
{
    /// <inheritdoc />
    public partial class Subscriptions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Subscriptions",
                columns: table => new
                {
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    BillingId = table.Column<Guid>(type: "uuid", nullable: false),
                    PremiumUntil = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    Source = table.Column<int>(type: "integer", nullable: false),
                    ProductId = table.Column<string>(type: "text", nullable: true),
                    LastEventAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Subscriptions", x => x.FamilyId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Subscriptions_BillingId",
                table: "Subscriptions",
                column: "BillingId",
                unique: true);

            // Every family already here keeps everything, for good. They were
            // using this before there was a price, and a migration that
            // quietly took the map and the shopping photos off them would be
            // a strange way to introduce one. Source 3 is Granted, and the
            // date is Subscription.Forever.
            migrationBuilder.Sql("""
                INSERT INTO "Subscriptions"
                    ("FamilyId", "BillingId", "PremiumUntil", "Source", "UpdatedAt")
                SELECT f."Id", gen_random_uuid(),
                       TIMESTAMPTZ '9999-12-31 23:59:59+00', 3, now()
                FROM "Families" f;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Subscriptions");
        }
    }
}
