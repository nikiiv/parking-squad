defmodule ParkingSqad.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending approved denied)

  schema "users" do
    field(:email, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:name, :string)
    field(:role, :string, default: "user")
    field(:status, :string, default: "pending")

    has_many(:owned_spots, ParkingSqad.Parking.ParkingSpot, foreign_key: :owner_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  A changeset for registration. Validates email is a gmail address,
  hashes the password, and requires name. Status defaults to "pending".
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name, :role, :status])
    |> validate_required([:email, :password, :name])
    |> validate_email()
    |> validate_password()
    |> validate_inclusion(:status, @statuses)
    |> put_password_hash()
  end

  @doc """
  A changeset for re-registration (denied user applying again).
  Resets status to pending and allows updating password and name.
  """
  def re_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :name])
    |> validate_required([:password, :name])
    |> validate_password()
    |> put_change(:status, "pending")
    |> put_password_hash()
  end

  @doc """
  A changeset for updating user profile fields (not password).
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :role])
    |> validate_required([:name])
    |> validate_inclusion(:role, ~w(admin user))
  end

  @doc """
  A changeset for updating user status (admin approval/denial).
  """
  def status_changeset(user, status) when status in @statuses do
    user
    |> change(status: status)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@gmail\.com$/, message: "must be a gmail.com address")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, hashed_password: Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset

  @doc """
  Verifies the password against the hashed password.
  """
  def valid_password?(%__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
