defmodule ParkingSqad.Repo.Migrations.CreateParkingSpots do
  use Ecto.Migration

  def change do
    create table(:parking_spots) do
      add(:spot_number, :string, null: false)
      add(:owner_id, references(:users, on_delete: :restrict), null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:parking_spots, [:spot_number]))
    create(index(:parking_spots, [:owner_id]))
  end
end
