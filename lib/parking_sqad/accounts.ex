defmodule ParkingSqad.Accounts do
  @moduledoc """
  The Accounts context. Handles user registration, authentication,
  admin approval workflow, and user lookups.
  """

  import Ecto.Query
  alias ParkingSqad.Repo
  alias ParkingSqad.Accounts.User
  alias ParkingSqad.Audit

  @topic "admin:users"

  # ── PubSub ─────────────────────────────────────────────────────────

  @doc """
  Subscribe to user management events.
  """
  def subscribe do
    Phoenix.PubSub.subscribe(ParkingSqad.PubSub, @topic)
  end

  defp broadcast({:ok, user}, event) do
    Phoenix.PubSub.broadcast(ParkingSqad.PubSub, @topic, {event, user})
    {:ok, user}
  end

  defp broadcast({:error, _} = error, _event), do: error

  # ── Registration ───────────────────────────────────────────────────

  @doc """
  Registers a new user or re-registers a denied user.

  Logic:
  - Email doesn't exist → create new user with status "pending"
  - Email exists, status "denied" → update to "pending" with new password/name
  - Email exists, status "pending" → error: registration already pending
  - Email exists, status "approved" → error: account already exists
  """
  def register_user(attrs) do
    email = Map.get(attrs, :email) || Map.get(attrs, "email")

    case get_user_by_email(email) do
      nil ->
        create_new_user(attrs)

      %User{status: "denied"} = user ->
        re_register_user(user, attrs)

      %User{status: "pending"} ->
        {:error, :registration_pending}

      %User{status: "approved"} ->
        {:error, :already_registered}
    end
  end

  defp create_new_user(attrs) do
    result =
      %User{}
      |> User.registration_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} ->
        Audit.log(%{
          user_id: user.id,
          action: "user_registered",
          details: %{email: user.email}
        })

        broadcast({:ok, user}, :user_registered)

      error ->
        error
    end
  end

  defp re_register_user(user, attrs) do
    result =
      user
      |> User.re_registration_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_user} ->
        Audit.log(%{
          user_id: updated_user.id,
          action: "user_re_registered",
          details: %{email: updated_user.email}
        })

        broadcast({:ok, updated_user}, :user_registered)

      error ->
        error
    end
  end

  # ── Admin Approval ─────────────────────────────────────────────────

  @doc """
  Admin approves a pending user.
  """
  def approve_user(%User{status: "pending"} = user, %User{role: "admin"} = admin) do
    result =
      user
      |> User.status_changeset("approved")
      |> Repo.update()

    case result do
      {:ok, approved_user} ->
        Audit.log(%{
          user_id: admin.id,
          action: "user_approved",
          details: %{approved_user_id: approved_user.id, email: approved_user.email}
        })

        broadcast({:ok, approved_user}, :user_updated)

      error ->
        error
    end
  end

  def approve_user(%User{}, _admin), do: {:error, :not_pending}
  def approve_user(_, _), do: {:error, :unauthorized}

  @doc """
  Admin denies a pending user.
  """
  def deny_user(%User{status: "pending"} = user, %User{role: "admin"} = admin) do
    result =
      user
      |> User.status_changeset("denied")
      |> Repo.update()

    case result do
      {:ok, denied_user} ->
        Audit.log(%{
          user_id: admin.id,
          action: "user_denied",
          details: %{denied_user_id: denied_user.id, email: denied_user.email}
        })

        broadcast({:ok, denied_user}, :user_updated)

      error ->
        error
    end
  end

  def deny_user(%User{}, _admin), do: {:error, :not_pending}
  def deny_user(_, _), do: {:error, :unauthorized}

  @doc """
  Admin disables an approved user (sets status to "denied").
  Admin cannot disable themselves.
  """
  def disable_user(%User{status: "approved"} = user, %User{role: "admin"} = admin) do
    if user.id == admin.id do
      {:error, :cannot_disable_self}
    else
      result =
        user
        |> User.status_changeset("denied")
        |> Repo.update()

      case result do
        {:ok, disabled_user} ->
          Audit.log(%{
            user_id: admin.id,
            action: "user_disabled",
            details: %{disabled_user_id: disabled_user.id, email: disabled_user.email}
          })

          broadcast({:ok, disabled_user}, :user_updated)

        error ->
          error
      end
    end
  end

  def disable_user(%User{}, _admin), do: {:error, :not_approved}
  def disable_user(_, _), do: {:error, :unauthorized}

  @doc """
  Admin enables a denied user (sets status to "approved").
  """
  def enable_user(%User{status: "denied"} = user, %User{role: "admin"} = admin) do
    result =
      user
      |> User.status_changeset("approved")
      |> Repo.update()

    case result do
      {:ok, enabled_user} ->
        Audit.log(%{
          user_id: admin.id,
          action: "user_enabled",
          details: %{enabled_user_id: enabled_user.id, email: enabled_user.email}
        })

        broadcast({:ok, enabled_user}, :user_updated)

      error ->
        error
    end
  end

  def enable_user(%User{}, _admin), do: {:error, :not_denied}
  def enable_user(_, _), do: {:error, :unauthorized}

  # ── Queries ────────────────────────────────────────────────────────

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_email(_), do: nil

  @doc """
  Gets a user by email and password. Returns nil if credentials are invalid.
  Does NOT check status — caller must check status separately.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) do
      user
    end
  end

  @doc """
  Gets a single user by id. Raises if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by id. Returns nil if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Lists all users ordered by name.
  """
  def list_users do
    Repo.all(from(u in User, order_by: [asc: u.name]))
  end

  @doc """
  Lists users with a specific status.
  """
  def list_users_by_status(status) when status in ~w(pending approved denied) do
    Repo.all(
      from(u in User,
        where: u.status == ^status,
        order_by: [asc: u.inserted_at]
      )
    )
  end

  @doc """
  Lists pending users (for admin approval page).
  """
  def list_pending_users do
    list_users_by_status("pending")
  end

  # ── Helpers ────────────────────────────────────────────────────────

  @doc """
  Returns true if the user has the admin role.
  """
  def admin?(%User{role: "admin"}), do: true
  def admin?(_), do: false

  @doc """
  Returns true if the user's status is approved.
  """
  def approved?(%User{status: "approved"}), do: true
  def approved?(_), do: false

  @doc """
  Returns true if the user owns any parking spot.
  """
  def spot_owner?(%User{} = user) do
    alias ParkingSqad.Parking.ParkingSpot

    Repo.exists?(from(ps in ParkingSpot, where: ps.owner_id == ^user.id))
  end
end
