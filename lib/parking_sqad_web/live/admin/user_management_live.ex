defmodule ParkingSqadWeb.Admin.UserManagementLive do
  use ParkingSqadWeb, :live_view

  alias ParkingSqad.Accounts
  alias ParkingSqad.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div>
        <h1 class="text-2xl font-bold text-ctp-mauve">User Management</h1>
        <p class="text-ctp-subtext0 mt-1">Review and manage user registrations</p>
      </div>

      <%!-- Filter tabs --%>
      <div class="flex gap-2">
        <button
          :for={status <- ~w(all pending approved denied)}
          phx-click="filter"
          phx-value-status={status}
          class={[
            "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
            if(@filter == status,
              do: "bg-ctp-mauve text-ctp-crust",
              else: "bg-ctp-surface0 text-ctp-subtext1 hover:bg-ctp-surface1"
            )
          ]}
        >
          <%= String.capitalize(status) %>
          <%= if status != "all" do %>
            <span class={[
              "ml-1.5 inline-flex items-center justify-center px-1.5 py-0.5 text-xs rounded-full",
              if(@filter == status,
                do: "bg-ctp-crust/30 text-ctp-crust",
                else: "bg-ctp-surface2 text-ctp-subtext0"
              )
            ]}>
              <%= count_by_status(@users_all, status) %>
            </span>
          <% end %>
        </button>
      </div>

      <%!-- Users table --%>
      <div class="card !p-0 overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-ctp-surface1">
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Name
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Email
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Status
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Registered
              </th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody id="users-table">
            <tr
              :for={user <- @users}
              :if={@users != []}
              id={"user-#{user.id}"}
              class="border-b border-ctp-surface0 last:border-0 hover:bg-ctp-surface0/50 transition-colors"
            >
              <td class="px-4 py-3 text-sm text-ctp-text">
                <%= user.name %>
                <%= if user.role == "admin" do %>
                  <span class="ml-1.5 text-xs bg-ctp-mauve/20 text-ctp-mauve px-1.5 py-0.5 rounded">
                    admin
                  </span>
                <% end %>
              </td>
              <td class="px-4 py-3 text-sm text-ctp-subtext1">
                <%= user.email %>
              </td>
              <td class="px-4 py-3 text-sm">
                <.status_badge status={user.status} />
              </td>
              <td class="px-4 py-3 text-sm text-ctp-subtext0">
                <%= Calendar.strftime(user.inserted_at, "%b %d, %Y") %>
              </td>
              <td class="px-4 py-3 text-right">
                <.user_actions user={user} current_user_id={@current_user.id} />
              </td>
            </tr>
            <tr :if={@users == []}>
              <td colspan="5" class="px-4 py-8 text-center text-ctp-subtext0">
                No users found.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :user, :map, required: true
  attr :current_user_id, :integer, required: true

  defp user_actions(assigns) do
    ~H"""
    <div class="flex gap-2 justify-end">
      <%= case @user.status do %>
        <% "pending" -> %>
          <button
            phx-click="approve"
            phx-value-id={@user.id}
            class="btn-success !py-1 !px-3 text-xs"
          >
            Approve
          </button>
          <button
            phx-click="deny"
            phx-value-id={@user.id}
            class="btn-danger !py-1 !px-3 text-xs"
          >
            Deny
          </button>
        <% "approved" -> %>
          <%= if @user.id != @current_user_id do %>
            <button
              phx-click="disable"
              phx-value-id={@user.id}
              data-confirm={"Disable #{@user.name}? They will no longer be able to log in."}
              class="btn-danger !py-1 !px-3 text-xs"
            >
              Disable
            </button>
          <% end %>
        <% "denied" -> %>
          <button
            phx-click="enable"
            phx-value-id={@user.id}
            class="btn-success !py-1 !px-3 text-xs"
          >
            Enable
          </button>
        <% _ -> %>
      <% end %>
    </div>
    """
  end

  attr :status, :string, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      status_color(@status)
    ]}>
      <%= @status %>
    </span>
    """
  end

  defp status_color("pending"), do: "bg-ctp-yellow/20 text-ctp-yellow"
  defp status_color("approved"), do: "bg-ctp-green/20 text-ctp-green"
  defp status_color("denied"), do: "bg-ctp-red/20 text-ctp-red"
  defp status_color(_), do: "bg-ctp-surface2 text-ctp-subtext0"

  defp count_by_status(users, status) do
    Enum.count(users, &(&1.status == status))
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
    end

    users = Accounts.list_users()

    {:ok,
     assign(socket,
       users_all: users,
       users: users,
       filter: "all",
       page_title: "User Management"
     )}
  end

  # ── PubSub handlers ────────────────────────────────────────────────

  @impl true
  def handle_info({:user_registered, _user}, socket) do
    refresh(socket, "New registration received.")
  end

  def handle_info({:user_updated, _user}, socket) do
    refresh(socket)
  end

  defp refresh(socket, flash_msg \\ nil) do
    users = Accounts.list_users()
    filtered = apply_filter(users, socket.assigns.filter)

    socket =
      socket
      |> assign(users_all: users, users: filtered)

    socket = if flash_msg, do: put_flash(socket, :info, flash_msg), else: socket

    {:noreply, socket}
  end

  # ── Event handlers ─────────────────────────────────────────────────

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    filtered =
      if status == "all" do
        socket.assigns.users_all
      else
        Enum.filter(socket.assigns.users_all, &(&1.status == status))
      end

    {:noreply, assign(socket, users: filtered, filter: status)}
  end

  def handle_event("approve", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.approve_user(user, socket.assigns.current_user) do
      {:ok, approved_user} ->
        Notifications.notify_registration_approved(approved_user)
        {:noreply, put_flash(socket, :info, "#{approved_user.name} has been approved.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to approve user.")}
    end
  end

  def handle_event("deny", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.deny_user(user, socket.assigns.current_user) do
      {:ok, denied_user} ->
        Notifications.notify_registration_denied(denied_user)
        {:noreply, put_flash(socket, :info, "#{denied_user.name} has been denied.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to deny user.")}
    end
  end

  def handle_event("disable", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.disable_user(user, socket.assigns.current_user) do
      {:ok, disabled_user} ->
        Notifications.notify_account_disabled(disabled_user)
        {:noreply, put_flash(socket, :info, "#{disabled_user.name} has been disabled.")}

      {:error, :cannot_disable_self} ->
        {:noreply, put_flash(socket, :error, "You cannot disable your own account.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to disable user.")}
    end
  end

  def handle_event("enable", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.enable_user(user, socket.assigns.current_user) do
      {:ok, enabled_user} ->
        Notifications.notify_account_enabled(enabled_user)
        {:noreply, put_flash(socket, :info, "#{enabled_user.name} has been enabled.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to enable user.")}
    end
  end

  defp apply_filter(users, "all"), do: users
  defp apply_filter(users, status), do: Enum.filter(users, &(&1.status == status))
end
