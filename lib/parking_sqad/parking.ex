defmodule ParkingSqad.Parking do
  @moduledoc """
  The Parking context. Manages parking spots and daily reservations.

  State machine for a spot on a given date:
  - No reservation record → spot belongs to owner (default)
  - Record with status "released" → available for claiming
  - Record with status "claimed" → claimed by another user
  - Spot disabled → cannot be released or claimed
  """

  import Ecto.Query
  alias ParkingSqad.Repo
  alias ParkingSqad.Parking.{ParkingSpot, Reservation}
  alias ParkingSqad.Accounts.User
  alias ParkingSqad.Audit

  @topic "admin:spots"
  @reservation_topic "parking:reservations"

  # ── PubSub ─────────────────────────────────────────────────────────

  @doc """
  Subscribe to spot management events (admin).
  """
  def subscribe_spots do
    Phoenix.PubSub.subscribe(ParkingSqad.PubSub, @topic)
  end

  @doc """
  Subscribe to reservation change events (dashboard).
  """
  def subscribe_reservations do
    Phoenix.PubSub.subscribe(ParkingSqad.PubSub, @reservation_topic)
  end

  defp broadcast_spot({:ok, spot}, event) do
    Phoenix.PubSub.broadcast(ParkingSqad.PubSub, @topic, {event, spot})
    {:ok, spot}
  end

  defp broadcast_spot({:error, _} = error, _event), do: error

  defp broadcast_reservation(date) do
    Phoenix.PubSub.broadcast(
      ParkingSqad.PubSub,
      @reservation_topic,
      {:reservation_changed, %{date: date}}
    )
  end

  # ── Parking Spot CRUD (admin) ──────────────────────────────────────

  @doc """
  Returns the next spot number (max existing + 1, or 1 if none).
  """
  def next_spot_number do
    Repo.one(from(ps in ParkingSpot, select: coalesce(max(ps.spot_number), 0))) + 1
  end

  @doc """
  Lists all parking spots with their owners preloaded.
  """
  def list_spots do
    ParkingSpot
    |> preload(:owner)
    |> order_by(asc: :spot_number)
    |> Repo.all()
  end

  @doc """
  Gets a single parking spot. Raises if not found.
  """
  def get_spot!(id) do
    ParkingSpot
    |> preload(:owner)
    |> Repo.get!(id)
  end

  @doc """
  Creates a parking spot with auto-assigned spot_number (admin only).
  attrs should contain :owner_id.
  """
  def create_spot(attrs, admin_user) do
    spot_number = next_spot_number()

    attrs = Map.put(attrs, :spot_number, spot_number)

    result =
      %ParkingSpot{}
      |> ParkingSpot.create_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, spot} ->
        Audit.log(%{
          user_id: admin_user.id,
          action: "spot_created",
          parking_spot_id: spot.id,
          details: %{spot_number: spot.spot_number, owner_id: spot.owner_id}
        })

        spot = Repo.preload(spot, :owner)
        broadcast_spot({:ok, spot}, :spot_created)

      error ->
        error
    end
  end

  @doc """
  Reassigns a parking spot's owner (admin only).
  """
  def update_spot_owner(%ParkingSpot{} = spot, %{owner_id: _} = attrs, admin_user) do
    previous_owner_id = spot.owner_id

    result =
      spot
      |> ParkingSpot.update_owner_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_spot} ->
        Audit.log(%{
          user_id: admin_user.id,
          action: "spot_updated",
          parking_spot_id: updated_spot.id,
          details: %{
            spot_number: updated_spot.spot_number,
            previous_owner_id: previous_owner_id,
            new_owner_id: updated_spot.owner_id
          }
        })

        updated_spot = Repo.preload(updated_spot, :owner, force: true)
        broadcast_spot({:ok, updated_spot}, :spot_updated)

      error ->
        error
    end
  end

  @doc """
  Disables a parking spot. Deletes all future reservations for this spot.
  """
  def disable_spot(%ParkingSpot{disabled: false} = spot, admin_user) do
    today = Date.utc_today()

    # Delete future reservations
    from(r in Reservation,
      where: r.parking_spot_id == ^spot.id and r.date > ^today
    )
    |> Repo.delete_all()

    result =
      spot
      |> ParkingSpot.disable_changeset(true)
      |> Repo.update()

    case result do
      {:ok, disabled_spot} ->
        Audit.log(%{
          user_id: admin_user.id,
          action: "spot_disabled",
          parking_spot_id: disabled_spot.id,
          details: %{spot_number: disabled_spot.spot_number}
        })

        disabled_spot = Repo.preload(disabled_spot, :owner, force: true)
        broadcast_spot({:ok, disabled_spot}, :spot_disabled)

      error ->
        error
    end
  end

  def disable_spot(%ParkingSpot{disabled: true}, _admin_user), do: {:error, :already_disabled}

  @doc """
  Enables a previously disabled parking spot.
  """
  def enable_spot(%ParkingSpot{disabled: true} = spot, admin_user) do
    result =
      spot
      |> ParkingSpot.disable_changeset(false)
      |> Repo.update()

    case result do
      {:ok, enabled_spot} ->
        Audit.log(%{
          user_id: admin_user.id,
          action: "spot_enabled",
          parking_spot_id: enabled_spot.id,
          details: %{spot_number: enabled_spot.spot_number}
        })

        enabled_spot = Repo.preload(enabled_spot, :owner, force: true)
        broadcast_spot({:ok, enabled_spot}, :spot_enabled)

      error ->
        error
    end
  end

  def enable_spot(%ParkingSpot{disabled: false}, _admin_user), do: {:error, :not_disabled}

  # ── Approved users for owner dropdown ──────────────────────────────

  @doc """
  Lists approved users (for owner selection dropdowns).
  """
  def list_approved_users do
    User
    |> where([u], u.status == "approved")
    |> order_by(asc: :name)
    |> Repo.all()
  end

  # ── Reservations ───────────────────────────────────────────────────

  @doc """
  Returns reservation counts for each date in a given month.
  Returns a map: %{date => %{released: count, claimed: count}}
  """
  def reservation_summary_for_month(year, month) do
    first_day = Date.new!(year, month, 1)
    last_day = Date.end_of_month(first_day)

    query =
      from(r in Reservation,
        join: ps in ParkingSpot,
        on: ps.id == r.parking_spot_id,
        where: r.date >= ^first_day and r.date <= ^last_day and ps.disabled == false,
        group_by: [r.date, r.status],
        select: {r.date, r.status, count(r.id)}
      )

    Repo.all(query)
    |> Enum.reduce(%{}, fn {date, status, count}, acc ->
      date_entry = Map.get(acc, date, %{released: 0, claimed: 0})

      date_entry =
        case status do
          "released" -> %{date_entry | released: count}
          "claimed" -> %{date_entry | claimed: count}
          _ -> date_entry
        end

      Map.put(acc, date, date_entry)
    end)
  end

  @doc """
  Returns a list of spots with their reservation status for a given date.
  Each entry is a map with keys: spot, status, reservation, claimed_by.
  Status is one of: :owner, :released, :claimed, :disabled.
  """
  def list_spots_for_date(date) do
    spots = list_spots()

    reservations =
      Reservation
      |> where([r], r.date == ^date)
      |> preload(:claimed_by)
      |> Repo.all()
      |> Map.new(&{&1.parking_spot_id, &1})

    Enum.map(spots, fn spot ->
      if spot.disabled do
        %{spot: spot, status: :disabled, reservation: nil, claimed_by: nil}
      else
        case Map.get(reservations, spot.id) do
          nil ->
            %{spot: spot, status: :owner, reservation: nil, claimed_by: nil}

          %Reservation{status: "released"} = res ->
            %{spot: spot, status: :released, reservation: res, claimed_by: nil}

          %Reservation{status: "claimed"} = res ->
            %{spot: spot, status: :claimed, reservation: res, claimed_by: res.claimed_by}
        end
      end
    end)
  end

  @doc """
  Owner releases their spot for a specific date, making it available.
  """
  def release_spot(%ParkingSpot{disabled: true}, _date, _owner), do: {:error, :spot_disabled}

  def release_spot(%ParkingSpot{} = spot, date, %{id: owner_id} = _owner) do
    if spot.owner_id != owner_id do
      {:error, :not_owner}
    else
      result =
        %Reservation{}
        |> Reservation.release_changeset(%{
          parking_spot_id: spot.id,
          date: date,
          status: "released"
        })
        |> Repo.insert()

      case result do
        {:ok, reservation} ->
          Audit.log(%{
            user_id: owner_id,
            action: "spot_released",
            parking_spot_id: spot.id,
            date: date,
            details: %{spot_number: spot.spot_number}
          })

          broadcast_reservation(date)
          {:ok, reservation}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  A user claims an available (released) spot for a specific date.
  """
  def claim_spot(%ParkingSpot{disabled: true}, _date, _user), do: {:error, :spot_disabled}

  def claim_spot(%ParkingSpot{} = spot, date, %{id: user_id} = _user) do
    reservation = Repo.get_by(Reservation, parking_spot_id: spot.id, date: date)

    case reservation do
      nil ->
        {:error, :not_available}

      %Reservation{status: "released"} ->
        result =
          reservation
          |> Reservation.claim_changeset(%{status: "claimed", claimed_by_id: user_id})
          |> Repo.update()

        case result do
          {:ok, updated} ->
            Audit.log(%{
              user_id: user_id,
              action: "spot_claimed",
              parking_spot_id: spot.id,
              date: date,
              details: %{spot_number: spot.spot_number}
            })

            broadcast_reservation(date)
            {:ok, updated}

          error ->
            error
        end

      %Reservation{status: "claimed"} ->
        {:error, :already_claimed}
    end
  end

  @doc """
  Owner forcefully reclaims their spot (deletes the reservation record).
  """
  def reclaim_spot(%ParkingSpot{} = spot, date, %{id: owner_id} = _owner) do
    if spot.owner_id != owner_id do
      {:error, :not_owner}
    else
      reservation = Repo.get_by(Reservation, parking_spot_id: spot.id, date: date)

      case reservation do
        nil ->
          {:error, :already_owned}

        %Reservation{} = res ->
          details = %{spot_number: spot.spot_number}

          details =
            if res.claimed_by_id,
              do: Map.put(details, :previous_claimer_id, res.claimed_by_id),
              else: details

          case Repo.delete(res) do
            {:ok, _} ->
              Audit.log(%{
                user_id: owner_id,
                action: "spot_reclaimed",
                parking_spot_id: spot.id,
                date: date,
                details: details
              })

              broadcast_reservation(date)
              :ok

            error ->
              error
          end
      end
    end
  end

  @doc """
  User who claimed a spot releases their claim (reverts to "released" status).
  """
  def release_claim(%ParkingSpot{} = spot, date, %{id: user_id} = _user) do
    reservation = Repo.get_by(Reservation, parking_spot_id: spot.id, date: date)

    case reservation do
      %Reservation{status: "claimed", claimed_by_id: ^user_id} ->
        result =
          reservation
          |> Reservation.claim_changeset(%{status: "released", claimed_by_id: nil})
          |> Repo.update()

        case result do
          {:ok, updated} ->
            Audit.log(%{
              user_id: user_id,
              action: "claim_released",
              parking_spot_id: spot.id,
              date: date,
              details: %{spot_number: spot.spot_number}
            })

            broadcast_reservation(date)
            {:ok, updated}

          error ->
            error
        end

      %Reservation{status: "claimed"} ->
        {:error, :not_claimer}

      _ ->
        {:error, :not_claimed}
    end
  end

  @doc """
  Gets spots owned by a specific user.
  """
  def list_spots_by_owner(owner_id) do
    ParkingSpot
    |> where([ps], ps.owner_id == ^owner_id)
    |> preload(:owner)
    |> order_by(asc: :spot_number)
    |> Repo.all()
  end
end
