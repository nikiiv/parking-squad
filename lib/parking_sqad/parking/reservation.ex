defmodule ParkingSqad.Parking.Reservation do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(released claimed)

  schema "reservations" do
    field(:date, :date)
    field(:status, :string)

    belongs_to(:parking_spot, ParkingSqad.Parking.ParkingSpot)
    belongs_to(:claimed_by, ParkingSqad.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for releasing a spot (owner makes it available).
  """
  def release_changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:parking_spot_id, :date, :status])
    |> validate_required([:parking_spot_id, :date, :status])
    |> validate_inclusion(:status, @statuses)
    |> put_change(:claimed_by_id, nil)
    |> unique_constraint([:parking_spot_id, :date])
  end

  @doc """
  Changeset for claiming a released spot.
  """
  def claim_changeset(reservation, attrs) do
    reservation
    |> cast(attrs, [:status, :claimed_by_id])
    |> validate_required([:status, :claimed_by_id])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:claimed_by_id)
  end
end
