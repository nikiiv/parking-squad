defmodule ParkingSqad.Repo.Migrations.AddDisabledAndFixSpotNumber do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TABLE parking_spots ALTER COLUMN spot_number TYPE integer USING spot_number::integer"
    )

    alter table(:parking_spots) do
      add(:disabled, :boolean, default: false, null: false)
    end
  end

  def down do
    alter table(:parking_spots) do
      remove(:disabled)
    end

    execute(
      "ALTER TABLE parking_spots ALTER COLUMN spot_number TYPE varchar USING spot_number::varchar"
    )
  end
end
