defmodule ParkingSqad.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @actions ~w(
    spot_released spot_claimed spot_reclaimed claim_released
    user_registered user_re_registered user_approved user_denied
    user_disabled user_enabled
    spot_created spot_updated spot_deleted spot_disabled spot_enabled
  )

  schema "audit_logs" do
    field(:action, :string)
    field(:date, :date)
    field(:details, :map)

    belongs_to(:user, ParkingSqad.Accounts.User)
    belongs_to(:parking_spot, ParkingSqad.Parking.ParkingSpot)

    # Append-only: only inserted_at, no updated_at
    field(:inserted_at, :utc_datetime, read_after_writes: true)
  end

  @doc """
  Changeset for creating an audit log entry.
  """
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:user_id, :action, :parking_spot_id, :date, :details])
    |> validate_required([:user_id, :action])
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parking_spot_id)
  end
end
