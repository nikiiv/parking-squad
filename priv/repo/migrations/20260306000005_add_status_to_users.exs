defmodule ParkingSqad.Repo.Migrations.AddStatusToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:status, :string, null: false, default: "pending")
    end

    create(index(:users, [:status]))

    # Set existing users (admin) to approved
    execute(
      "UPDATE users SET status = 'approved' WHERE role = 'admin'",
      "SELECT 1"
    )
  end
end
