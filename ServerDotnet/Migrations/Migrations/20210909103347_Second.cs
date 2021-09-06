using Microsoft.EntityFrameworkCore.Migrations;

namespace Migrations.Migrations
{
    public partial class Second : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "password_password_salt",
                table: "link",
                newName: "password_salt");

            migrationBuilder.RenameColumn(
                name: "password_password_hash",
                table: "link",
                newName: "password_hash");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "password_salt",
                table: "link",
                newName: "password_password_salt");

            migrationBuilder.RenameColumn(
                name: "password_hash",
                table: "link",
                newName: "password_password_hash");
        }
    }
}
