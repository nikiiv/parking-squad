defmodule ParkingSqad.Parking.ParkingSpot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "parking_spots" do
    field(:spot_number, :integer)
    field(:disabled, :boolean, default: false)

    belongs_to(:owner, ParkingSqad.Accounts.User)
    has_many(:reservations, ParkingSqad.Parking.Reservation)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a parking spot.
  spot_number is auto-assigned by the context, not user-provided.
  """
  def create_changeset(parking_spot, attrs) do
    parking_spot
    |> cast(attrs, [:spot_number, :owner_id])
    |> validate_required([:spot_number, :owner_id])
    |> unique_constraint(:spot_number)
    |> foreign_key_constraint(:owner_id)
  end

  @doc """
  Changeset for reassigning a spot's owner.
  """
  def update_owner_changeset(parking_spot, attrs) do
    parking_spot
    |> cast(attrs, [:owner_id])
    |> validate_required([:owner_id])
    |> foreign_key_constraint(:owner_id)
  end

  @doc """
  Changeset for toggling the disabled flag.
  """
  def disable_changeset(parking_spot, disabled) when is_boolean(disabled) do
    parking_spot
    |> change(disabled: disabled)
  end
end
