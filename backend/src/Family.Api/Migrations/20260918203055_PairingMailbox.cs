using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Family.Api.Migrations
{
    /// <inheritdoc />
    public partial class PairingMailbox : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Mailbox",
                table: "PairingAdmissions",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_PairingAdmissions_Mailbox",
                table: "PairingAdmissions",
                column: "Mailbox");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_PairingAdmissions_Mailbox",
                table: "PairingAdmissions");

            migrationBuilder.DropColumn(
                name: "Mailbox",
                table: "PairingAdmissions");
        }
    }
}
