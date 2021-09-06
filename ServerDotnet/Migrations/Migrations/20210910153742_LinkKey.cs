using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

namespace Migrations.Migrations
{
    public partial class LinkKey : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropPrimaryKey(
                name: "pk_link",
                table: "link");

            migrationBuilder.DropColumn(
                name: "id",
                table: "link");

            migrationBuilder.RenameColumn(
                name: "short_url",
                table: "link",
                newName: "target");

            migrationBuilder.RenameColumn(
                name: "full_url",
                table: "link",
                newName: "key");

            migrationBuilder.AddPrimaryKey(
                name: "pk_link",
                table: "link",
                column: "key");

            migrationBuilder.CreateIndex(
                name: "ix_link_key",
                table: "link",
                column: "key",
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropPrimaryKey(
                name: "pk_link",
                table: "link");

            migrationBuilder.DropIndex(
                name: "ix_link_key",
                table: "link");

            migrationBuilder.RenameColumn(
                name: "target",
                table: "link",
                newName: "short_url");

            migrationBuilder.RenameColumn(
                name: "key",
                table: "link",
                newName: "full_url");

            migrationBuilder.AddColumn<int>(
                name: "id",
                table: "link",
                type: "integer",
                nullable: false,
                defaultValue: 0)
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AddPrimaryKey(
                name: "pk_link",
                table: "link",
                column: "id");
        }
    }
}
