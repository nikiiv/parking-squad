defmodule ParkingSqadWeb.UserRegistrationLive do
  use ParkingSqadWeb, :live_view

  alias ParkingSqad.Accounts
  alias ParkingSqad.Accounts.User
  alias ParkingSqad.Notifications

  def render(assigns) do
    ~H"""
    <div class="flex min-h-[80vh] items-center justify-center">
      <div class="card w-full max-w-md">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-ctp-mauve">🅿️ Parking Squad</h1>
          <p class="text-ctp-subtext0 mt-2">Create your account</p>
        </div>

        <.form
          for={@form}
          id="registration-form"
          phx-submit="save"
          phx-change="validate"
          class="space-y-5"
        >
          <div>
            <label for="user_name" class="block text-sm font-medium mb-1.5">Full name</label>
            <input
              type="text"
              name="user[name]"
              id="user_name"
              value={Phoenix.HTML.Form.input_value(@form, :name)}
              placeholder="John Doe"
              required
              phx-debounce="blur"
              class="w-full"
            />
            <.field_error form={@form} field={:name} />
          </div>

          <div>
            <label for="user_email" class="block text-sm font-medium mb-1.5">Email</label>
            <input
              type="email"
              name="user[email]"
              id="user_email"
              value={Phoenix.HTML.Form.input_value(@form, :email)}
              placeholder="you@gmail.com"
              required
              phx-debounce="blur"
              class="w-full"
            />
            <.field_error form={@form} field={:email} />
          </div>

          <div>
            <label for="user_password" class="block text-sm font-medium mb-1.5">Password</label>
            <input
              type="password"
              name="user[password]"
              id="user_password"
              value={Phoenix.HTML.Form.input_value(@form, :password)}
              placeholder="Minimum 6 characters"
              required
              phx-debounce="blur"
              class="w-full"
            />
            <.field_error form={@form} field={:password} />
          </div>

          <div>
            <button type="submit" phx-disable-with="Registering..." class="btn-primary w-full">
              Register
            </button>
          </div>
        </.form>

        <p class="mt-6 text-center text-sm text-ctp-subtext0">
          Already have an account?
          <a href={~p"/login"} class="link">Log in</a>
        </p>
      </div>
    </div>
    """
  end

  attr(:form, :any, required: true)
  attr(:field, :atom, required: true)

  defp field_error(assigns) do
    ~H"""
    <%= for error <- Enum.map(@form[@field].errors, &translate_error/1) do %>
      <p class="mt-1 text-xs text-ctp-red"><%= error %></p>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    changeset = User.registration_changeset(%User{}, %{})
    {:ok, assign(socket, form: to_form(changeset, as: :user), page_title: "Register")}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :user))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        Notifications.notify_registration_pending(user)

        {:noreply,
         socket
         |> put_flash(
           :info,
           "Registration submitted! Please wait for admin approval. Check your email for confirmation."
         )
         |> redirect(to: ~p"/login")}

      {:error, :registration_pending} ->
        {:noreply,
         socket
         |> put_flash(:error, "A registration for this email is already pending approval.")
         |> redirect(to: ~p"/login")}

      {:error, :already_registered} ->
        {:noreply,
         socket
         |> put_flash(:error, "An account with this email already exists.")
         |> redirect(to: ~p"/login")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :user))}
    end
  end
end
