defmodule ParkingSqad.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add(:user_id, references(:users, on_delete: :nilify_all))
      add(:action, :string, null: false)
      add(:parking_spot_id, references(:parking_spots, on_delete: :nilify_all))
      add(:date, :date)
      add(:details, :map)

      add(:inserted_at, :utc_datetime, null: false, default: fragment("now()"))
    end

    create(index(:audit_logs, [:user_id]))
    create(index(:audit_logs, [:parking_spot_id]))
    create(index(:audit_logs, [:action]))
    create(index(:audit_logs, [:inserted_at]))
  end
end
