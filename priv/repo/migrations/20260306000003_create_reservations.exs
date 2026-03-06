defmodule ParkingSqad.Repo.Migrations.CreateReservations do
  use Ecto.Migration

  def change do
    create table(:reservations) do
      add(:parking_spot_id, references(:parking_spots, on_delete: :delete_all), null: false)
      add(:date, :date, null: false)
      add(:status, :string, null: false)
      add(:claimed_by_id, references(:users, on_delete: :nilify_all))

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:reservations, [:parking_spot_id, :date]))
    create(index(:reservations, [:claimed_by_id]))
    create(index(:reservations, [:date]))
  end
end
