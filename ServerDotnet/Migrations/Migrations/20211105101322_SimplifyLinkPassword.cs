using Microsoft.EntityFrameworkCore.Migrations;

namespace Migrations.Migrations
{
    public partial class SimplifyLinkPassword : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "password_hash",
                table: "link");

            migrationBuilder.RenameColumn(
                name: "password_salt",
                table: "link",
                newName: "password");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "password",
                table: "link",
                newName: "password_salt");

            migrationBuilder.AddColumn<string>(
                name: "password_hash",
                table: "link",
                type: "text",
                nullable: true);
        }
    }
}
