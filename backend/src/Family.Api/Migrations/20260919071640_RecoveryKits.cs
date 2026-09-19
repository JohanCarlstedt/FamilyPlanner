using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Family.Api.Migrations
{
    /// <inheritdoc />
    public partial class RecoveryKits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "RecoveryKits",
                columns: table => new
                {
                    LookupId = table.Column<string>(type: "text", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    MemberId = table.Column<Guid>(type: "uuid", nullable: false),
                    DeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    Note = table.Column<byte[]>(type: "bytea", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecoveryKits", x => x.LookupId);
                });

            migrationBuilder.CreateIndex(
                name: "IX_RecoveryKits_MemberId",
                table: "RecoveryKits",
                column: "MemberId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "RecoveryKits");
        }
    }
}
