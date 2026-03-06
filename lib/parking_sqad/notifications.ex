defmodule ParkingSqad.Notifications do
  @moduledoc """
  High-level notification dispatcher. Builds emails and delivers them.
  All functions are fire-and-forget — errors are logged but not raised.
  """

  require Logger

  alias ParkingSqad.{Email, Mailer}

  # ── Registration Notifications ─────────────────────────────────────

  @doc """
  Sends email informing user their registration is pending approval.
  """
  def notify_registration_pending(user) do
    user
    |> Email.registration_pending()
    |> deliver()
  end

  @doc """
  Sends email informing user their registration has been approved.
  """
  def notify_registration_approved(user) do
    user
    |> Email.registration_approved()
    |> deliver()
  end

  @doc """
  Sends email informing user their registration has been denied.
  """
  def notify_registration_denied(user) do
    user
    |> Email.registration_denied()
    |> deliver()
  end

  # ── Account Status Notifications ───────────────────────────────────

  @doc """
  Sends email informing user their account has been disabled.
  """
  def notify_account_disabled(user) do
    user
    |> Email.account_disabled()
    |> deliver()
  end

  @doc """
  Sends email informing user their account has been enabled.
  """
  def notify_account_enabled(user) do
    user
    |> Email.account_enabled()
    |> deliver()
  end

  # ── Parking Spot Notifications ─────────────────────────────────────

  @doc """
  Sends a notification that a spot has been released.
  `recipients` is a list of users to notify.
  """
  def notify_spot_released(spot, date, recipients) when is_list(recipients) do
    Enum.each(recipients, fn recipient ->
      Email.spot_released(recipient, spot, date)
      |> deliver()
    end)
  end

  @doc """
  Notifies the spot owner that their spot has been claimed.
  """
  def notify_spot_claimed(spot, date, owner, claimer) do
    Email.spot_claimed(owner, spot, date, claimer)
    |> deliver()
  end

  @doc """
  Notifies the claimer that the owner has reclaimed their spot.
  """
  def notify_spot_reclaimed(spot, date, claimer) do
    Email.spot_reclaimed(claimer, spot, date)
    |> deliver()
  end

  @doc """
  Notifies the spot owner that a claim on their spot has been released.
  """
  def notify_claim_released(spot, date, owner, claimer) do
    Email.claim_released(owner, spot, date, claimer)
    |> deliver()
  end

  # ── Private ────────────────────────────────────────────────────────

  defp deliver(email) do
    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Email sent to #{inspect(email.to)}: #{email.subject}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to send email to #{inspect(email.to)}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
