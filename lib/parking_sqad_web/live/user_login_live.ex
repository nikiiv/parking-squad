defmodule ParkingSqadWeb.UserLoginLive do
  use ParkingSqadWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex min-h-[80vh] items-center justify-center">
      <div class="card w-full max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-ctp-mauve">🅿️ Parking Squad</h1>
          <p class="text-ctp-subtext0 mt-2">Sign in to your account</p>
        </div>

        <.form
          for={@form}
          id="login-form"
          action={~p"/login"}
          phx-update="ignore"
          class="space-y-5"
        >
          <div>
            <label for="email" class="block text-sm font-medium mb-1.5">Email</label>
            <input
              type="email"
              name="email"
              id="email"
              value={Phoenix.HTML.Form.input_value(@form, :email)}
              placeholder="you@gmail.com"
              required
              class="w-full"
            />
          </div>

          <div>
            <label for="password" class="block text-sm font-medium mb-1.5">Password</label>
            <input
              type="password"
              name="password"
              id="password"
              placeholder="••••••••"
              required
              class="w-full"
            />
          </div>

          <div>
            <button type="submit" class="btn-primary w-full">
              Sign in
            </button>
          </div>
        </.form>

        <p class="mt-6 text-center text-sm text-ctp-subtext0">
          Don't have an account?
          <a href={~p"/register"} class="link">Register</a>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: :user)
    {:ok, assign(socket, form: form, page_title: "Log in")}
  end
end
