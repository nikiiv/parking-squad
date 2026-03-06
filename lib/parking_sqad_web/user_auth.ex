defmodule ParkingSqadWeb.UserAuth do
  @moduledoc """
  Authentication plugs and helpers for the web layer.
  """

  use ParkingSqadWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias ParkingSqad.Accounts

  @doc """
  Fetches the current user from session and assigns it.
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  @doc """
  Requires that the user is authenticated (any status).
  Redirects to login if not.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  Requires that the authenticated user has status "approved".
  """
  def require_approved_user(conn, _opts) do
    case conn.assigns[:current_user] do
      %{status: "approved"} ->
        conn

      %{status: "pending"} ->
        conn
        |> put_flash(:error, "Your registration is pending approval.")
        |> log_out_user()

      %{status: "denied"} ->
        conn
        |> put_flash(:error, "Your registration has been denied. You may re-register.")
        |> log_out_user()

      _ ->
        conn
        |> redirect(to: ~p"/login")
        |> halt()
    end
  end

  @doc """
  Requires that the authenticated user is an admin.
  """
  def require_admin(conn, _opts) do
    if Accounts.admin?(conn.assigns[:current_user]) do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  @doc """
  Redirects to home if user is already authenticated and approved.
  Used for login/register pages.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] && conn.assigns.current_user.status == "approved" do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  @doc """
  Logs in the user by setting the session.
  """
  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
    |> redirect(to: ~p"/")
  end

  @doc """
  Logs out the user by clearing the session.
  """
  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      ParkingSqadWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/login")
    |> halt()
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  LiveView on_mount hook to assign current_user from session.
  """
  def on_mount(:default, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:ensure_approved, _params, session, socket) do
    socket = mount_current_user(socket, session)

    case socket.assigns[:current_user] do
      %{status: "approved"} ->
        {:cont, socket}

      _ ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "Your account is not approved.")
          |> Phoenix.LiveView.redirect(to: ~p"/login")

        {:halt, socket}
    end
  end

  def on_mount(:ensure_admin, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if Accounts.admin?(socket.assigns[:current_user]) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You are not authorized.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns[:current_user] && socket.assigns.current_user.status == "approved" do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      user_id = session["user_id"]
      user_id && Accounts.get_user(user_id)
    end)
  end
end
