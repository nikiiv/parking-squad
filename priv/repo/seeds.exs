# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias ParkingSqad.Repo
alias ParkingSqad.Accounts
alias ParkingSqad.Accounts.User

# Create the default admin user if it doesn't already exist
admin_email = "nikolay.ivanchev@gmail.com"

case Accounts.get_user_by_email(admin_email) do
  nil ->
    {:ok, _admin} =
      Accounts.register_user(%{
        email: admin_email,
        password: "123456",
        name: "Nikolay Ivanchev",
        role: "admin",
        status: "approved"
      })

    IO.puts("Default admin user created: #{admin_email}")

  %User{status: "approved"} ->
    IO.puts("Default admin user already exists and is approved: #{admin_email}")

  %User{} = user ->
    user
    |> Ecto.Changeset.change(role: "admin", status: "approved")
    |> Repo.update!()

    IO.puts("Default admin user updated to approved admin: #{admin_email}")
end
