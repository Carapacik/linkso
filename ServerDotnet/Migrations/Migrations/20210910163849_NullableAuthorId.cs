using Microsoft.EntityFrameworkCore.Migrations;

namespace Migrations.Migrations
{
    public partial class NullableAuthorId : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_link_user_user_id",
                table: "link");

            migrationBuilder.AlterColumn<int>(
                name: "user_id",
                table: "link",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AddForeignKey(
                name: "fk_link_user_user_id",
                table: "link",
                column: "user_id",
                principalTable: "user",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_link_user_user_id",
                table: "link");

            migrationBuilder.AlterColumn<int>(
                name: "user_id",
                table: "link",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "fk_link_user_user_id",
                table: "link",
                column: "user_id",
                principalTable: "user",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
