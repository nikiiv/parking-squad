defmodule ParkingSqad.Email do
  @moduledoc """
  Email template builder for Parking Squad notifications.
  Each function returns a %Swoosh.Email{} struct ready for delivery.
  """

  import Swoosh.Email

  @from {"Parking Squad", "noreply@ivanchev.org"}

  # ── Registration Emails ────────────────────────────────────────────

  @doc """
  Sent after a new user registers. Informs them their registration is pending.
  """
  def registration_pending(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Registration Pending — Parking Squad")
    |> text_body("""
    Hi #{user.name},

    Thank you for registering with Parking Squad!

    Your registration is currently pending admin approval. You will receive
    another email once your account has been reviewed.

    — Parking Squad
    """)
  end

  @doc """
  Sent when an admin approves a user's registration.
  """
  def registration_approved(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Registration Approved — Parking Squad")
    |> text_body("""
    Hi #{user.name},

    Great news! Your Parking Squad account has been approved.

    You can now log in and start using the system.

    — Parking Squad
    """)
  end

  @doc """
  Sent when an admin denies a user's registration.
  """
  def registration_denied(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Registration Denied — Parking Squad")
    |> text_body("""
    Hi #{user.name},

    Unfortunately, your Parking Squad registration has been denied.

    If you believe this was a mistake, you may register again at any time.

    — Parking Squad
    """)
  end

  # ── Account Status Emails ──────────────────────────────────────────

  @doc """
  Sent when an admin disables a previously approved user.
  """
  def account_disabled(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Account Disabled — Parking Squad")
    |> text_body("""
    Hi #{user.name},

    Your Parking Squad account has been disabled by an administrator.

    If you believe this was a mistake, please contact your admin.

    — Parking Squad
    """)
  end

  @doc """
  Sent when an admin enables a previously denied user.
  """
  def account_enabled(user) do
    new()
    |> to({user.name, user.email})
    |> from(@from)
    |> subject("Account Enabled — Parking Squad")
    |> text_body("""
    Hi #{user.name},

    Your Parking Squad account has been enabled by an administrator.

    You can now log in and start using the system.

    — Parking Squad
    """)
  end

  # ── Parking Spot Emails ────────────────────────────────────────────

  @doc """
  Notifies that a spot has been released and is available for claiming.
  """
  def spot_released(recipient, spot, date) do
    new()
    |> to({recipient.name, recipient.email})
    |> from(@from)
    |> subject("Parking spot #{spot.spot_number} available on #{Date.to_string(date)}")
    |> text_body("""
    Hi #{recipient.name},

    Parking spot #{spot.spot_number} has been released and is available for #{Date.to_string(date)}.

    Log in to claim it before someone else does!

    — Parking Squad
    """)
  end

  @doc """
  Notifies the spot owner that their released spot has been claimed.
  """
  def spot_claimed(owner, spot, date, claimer) do
    new()
    |> to({owner.name, owner.email})
    |> from(@from)
    |> subject("Your spot #{spot.spot_number} was claimed for #{Date.to_string(date)}")
    |> text_body("""
    Hi #{owner.name},

    Your parking spot #{spot.spot_number} has been claimed by #{claimer.name} (#{claimer.email}) for #{Date.to_string(date)}.

    You can reclaim it at any time by logging in.

    — Parking Squad
    """)
  end

  @doc """
  Notifies the claimer that the owner has reclaimed the spot.
  """
  def spot_reclaimed(claimer, spot, date) do
    new()
    |> to({claimer.name, claimer.email})
    |> from(@from)
    |> subject("Spot #{spot.spot_number} reclaimed by owner for #{Date.to_string(date)}")
    |> text_body("""
    Hi #{claimer.name},

    The owner has reclaimed parking spot #{spot.spot_number} for #{Date.to_string(date)}.

    Your reservation for this spot has been cancelled. You can try claiming another available spot.

    — Parking Squad
    """)
  end

  @doc """
  Notifies the spot owner that the claimer has released their claim.
  """
  def claim_released(owner, spot, date, claimer) do
    new()
    |> to({owner.name, owner.email})
    |> from(@from)
    |> subject("Claim on spot #{spot.spot_number} released for #{Date.to_string(date)}")
    |> text_body("""
    Hi #{owner.name},

    #{claimer.name} (#{claimer.email}) has released their claim on your parking spot #{spot.spot_number} for #{Date.to_string(date)}.

    The spot is now available for others to claim, or you can reclaim it.

    — Parking Squad
    """)
  end
end
