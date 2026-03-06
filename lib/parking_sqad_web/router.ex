defmodule ParkingSqadWeb.Router do
  use ParkingSqadWeb, :router

  import ParkingSqadWeb.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ParkingSqadWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Public routes — redirect authenticated+approved users away
  scope "/", ParkingSqadWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    live_session :redirect_if_authenticated,
      on_mount: [{ParkingSqadWeb.UserAuth, :redirect_if_authenticated}] do
      live("/login", UserLoginLive, :login)
      live("/register", UserRegistrationLive, :register)
    end
  end

  # Login form POST (non-LiveView — needs controller for session write)
  scope "/", ParkingSqadWeb do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    post("/login", UserSessionController, :create)
  end

  # Authenticated + approved routes
  scope "/", ParkingSqadWeb do
    pipe_through([:browser, :require_authenticated_user, :require_approved_user])

    live_session :require_authenticated,
      on_mount: [{ParkingSqadWeb.UserAuth, :ensure_authenticated}] do
      live("/", DashboardLive, :index)
    end

    delete("/logout", UserSessionController, :delete)
  end

  # Admin-only routes
  scope "/admin", ParkingSqadWeb.Admin do
    pipe_through([:browser, :require_authenticated_user, :require_approved_user, :require_admin])

    live_session :require_admin,
      on_mount: [
        {ParkingSqadWeb.UserAuth, :ensure_authenticated},
        {ParkingSqadWeb.UserAuth, :ensure_admin}
      ] do
      live("/users", UserManagementLive)
      live("/spots", SpotManagementLive)
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:parking_sqad, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ParkingSqadWeb.Telemetry)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
