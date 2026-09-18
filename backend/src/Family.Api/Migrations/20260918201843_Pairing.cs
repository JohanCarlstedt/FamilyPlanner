using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Family.Api.Migrations
{
    /// <inheritdoc />
    public partial class Pairing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DeviceEndorsements",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectDeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    EndorserDeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    Endorsement = table.Column<byte[]>(type: "bytea", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DeviceEndorsements", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PairingAdmissions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    ToDeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    FromDeviceId = table.Column<Guid>(type: "uuid", nullable: false),
                    Admission = table.Column<byte[]>(type: "bytea", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PairingAdmissions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DeviceEndorsements_FamilyId",
                table: "DeviceEndorsements",
                column: "FamilyId");

            migrationBuilder.CreateIndex(
                name: "IX_DeviceEndorsements_SubjectDeviceId_EndorserDeviceId",
                table: "DeviceEndorsements",
                columns: new[] { "SubjectDeviceId", "EndorserDeviceId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PairingAdmissions_ToDeviceId_CreatedAt",
                table: "PairingAdmissions",
                columns: new[] { "ToDeviceId", "CreatedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DeviceEndorsements");

            migrationBuilder.DropTable(
                name: "PairingAdmissions");
        }
    }
}
