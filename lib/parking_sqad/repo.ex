defmodule ParkingSqad.Repo do
  use Ecto.Repo,
    otp_app: :parking_sqad,
    adapter: Ecto.Adapters.Postgres
end
