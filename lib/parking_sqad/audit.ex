defmodule ParkingSqad.Audit do
  @moduledoc """
  The Audit context. Provides append-only audit logging for all system operations.
  """

  import Ecto.Query
  alias ParkingSqad.Repo
  alias ParkingSqad.Audit.AuditLog

  @doc """
  Creates an audit log entry. Accepts a map with:
  - :user_id (required) - who performed the action
  - :action (required) - what action was performed
  - :parking_spot_id (optional) - which spot was affected
  - :date (optional) - which date was affected
  - :details (optional) - additional context as a map
  """
  def log(attrs) when is_map(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit logs, most recent first. Supports optional filters.
  """
  def list_logs(opts \\ []) do
    query =
      AuditLog
      |> order_by(desc: :inserted_at)
      |> preload([:user, :parking_spot])

    query =
      case Keyword.get(opts, :user_id) do
        nil -> query
        user_id -> where(query, [a], a.user_id == ^user_id)
      end

    query =
      case Keyword.get(opts, :parking_spot_id) do
        nil -> query
        spot_id -> where(query, [a], a.parking_spot_id == ^spot_id)
      end

    query =
      case Keyword.get(opts, :action) do
        nil -> query
        action -> where(query, [a], a.action == ^action)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> limit(query, 100)
        n -> limit(query, ^n)
      end

    Repo.all(query)
  end

  @doc """
  Lists audit logs for a specific date.
  """
  def list_logs_for_date(date) do
    AuditLog
    |> where([a], a.date == ^date)
    |> order_by(desc: :inserted_at)
    |> preload([:user, :parking_spot])
    |> Repo.all()
  end
end
