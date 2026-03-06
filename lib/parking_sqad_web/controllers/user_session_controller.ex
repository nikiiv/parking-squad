defmodule ParkingSqadWeb.UserSessionController do
  use ParkingSqadWeb, :controller

  alias ParkingSqad.Accounts
  alias ParkingSqadWeb.UserAuth

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %{status: "approved"} = user ->
        conn
        |> put_flash(:info, "Welcome back, #{user.name}!")
        |> UserAuth.log_in_user(user)

      %{status: "pending"} ->
        conn
        |> put_flash(:error, "Your registration is pending admin approval.")
        |> put_flash(:email, email)
        |> redirect(to: ~p"/login")

      %{status: "denied"} ->
        conn
        |> put_flash(:error, "Your registration was denied. You may re-register.")
        |> redirect(to: ~p"/register")

      nil ->
        # Prevent timing attacks
        Bcrypt.no_user_verify()

        conn
        |> put_flash(:error, "Invalid email or password.")
        |> put_flash(:email, email)
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
