defmodule ParkingSqadWeb.Admin.SpotManagementLive do
  use ParkingSqadWeb, :live_view

  alias ParkingSqad.Parking

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-ctp-mauve">Spot Management</h1>
          <p class="text-ctp-subtext0 mt-1">Manage parking spots and their owners</p>
        </div>
        <button
          :if={!@show_add_form}
          phx-click="show_add_form"
          class="btn-primary"
        >
          + Add Spot
        </button>
      </div>

      <%!-- Add Spot Form --%>
      <div :if={@show_add_form} class="card">
        <h2 class="text-lg font-semibold text-ctp-text mb-4">
          Add New Spot
          <span class="text-sm font-normal text-ctp-subtext0 ml-2">
            Will be Spot #<%= @next_spot_number %>
          </span>
        </h2>
        <form phx-submit="create_spot" class="flex items-end gap-4">
          <div class="flex-1">
            <label class="block text-sm font-medium text-ctp-subtext1 mb-1">Owner</label>
            <select
              name="owner_id"
              required
              class="w-full rounded-lg bg-ctp-surface0 border border-ctp-surface2 text-ctp-text px-3 py-2 focus:outline-none focus:ring-2 focus:ring-ctp-mauve focus:border-transparent"
            >
              <option value="">Select an owner...</option>
              <option :for={user <- @approved_users} value={user.id}>
                <%= user.name %> (<%= user.email %>)
              </option>
            </select>
          </div>
          <div class="flex gap-2">
            <button type="submit" class="btn-success">Save</button>
            <button type="button" phx-click="cancel_add" class="btn-secondary">Cancel</button>
          </div>
        </form>
      </div>

      <%!-- Spots table --%>
      <div class="card !p-0 overflow-hidden">
        <table class="w-full">
          <thead>
            <tr class="border-b border-ctp-surface1">
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Spot #
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Owner
              </th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Status
              </th>
              <th class="text-right px-4 py-3 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody id="spots-table">
            <tr
              :for={spot <- @spots}
              :if={@spots != []}
              id={"spot-#{spot.id}"}
              class="border-b border-ctp-surface0 last:border-0 hover:bg-ctp-surface0/50 transition-colors"
            >
              <td class="px-4 py-3 text-sm text-ctp-text font-medium">
                #<%= spot.spot_number %>
              </td>
              <td class="px-4 py-3 text-sm text-ctp-subtext1">
                <%= if @reassigning_spot_id == spot.id do %>
                  <form phx-submit="save_reassign" class="flex items-center gap-2">
                    <input type="hidden" name="spot_id" value={spot.id} />
                    <select
                      name="owner_id"
                      required
                      class="rounded-lg bg-ctp-surface0 border border-ctp-surface2 text-ctp-text text-sm px-2 py-1 focus:outline-none focus:ring-2 focus:ring-ctp-mauve focus:border-transparent"
                    >
                      <option :for={user <- @approved_users} value={user.id} selected={user.id == spot.owner_id}>
                        <%= user.name %>
                      </option>
                    </select>
                    <button type="submit" class="btn-success !py-1 !px-3 text-xs">Save</button>
                    <button type="button" phx-click="cancel_reassign" class="btn-secondary !py-1 !px-3 text-xs">
                      Cancel
                    </button>
                  </form>
                <% else %>
                  <%= spot.owner.name %>
                <% end %>
              </td>
              <td class="px-4 py-3 text-sm">
                <.status_badge disabled={spot.disabled} />
              </td>
              <td class="px-4 py-3 text-right">
                <.spot_actions spot={spot} reassigning={@reassigning_spot_id == spot.id} />
              </td>
            </tr>
            <tr :if={@spots == []}>
              <td colspan="4" class="px-4 py-8 text-center text-ctp-subtext0">
                No parking spots yet. Click "Add Spot" to create the first one.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr(:disabled, :boolean, required: true)

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      if(@disabled, do: "bg-ctp-red/20 text-ctp-red", else: "bg-ctp-green/20 text-ctp-green")
    ]}>
      <%= if @disabled, do: "Disabled", else: "Active" %>
    </span>
    """
  end

  attr(:spot, :map, required: true)
  attr(:reassigning, :boolean, required: true)

  defp spot_actions(assigns) do
    ~H"""
    <div class="flex gap-2 justify-end">
      <%= if @spot.disabled do %>
        <button
          phx-click="enable"
          phx-value-id={@spot.id}
          class="btn-success !py-1 !px-3 text-xs"
        >
          Enable
        </button>
      <% else %>
        <button
          :if={!@reassigning}
          phx-click="reassign"
          phx-value-id={@spot.id}
          class="btn-secondary !py-1 !px-3 text-xs"
        >
          Reassign
        </button>
        <button
          :if={!@reassigning}
          phx-click="disable"
          phx-value-id={@spot.id}
          data-confirm={"Disable Spot ##{@spot.spot_number}? All future reservations will be deleted."}
          class="btn-danger !py-1 !px-3 text-xs"
        >
          Disable
        </button>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Parking.subscribe_spots()
    end

    {:ok,
     socket
     |> assign(
       spots: Parking.list_spots(),
       approved_users: Parking.list_approved_users(),
       next_spot_number: Parking.next_spot_number(),
       show_add_form: false,
       reassigning_spot_id: nil,
       page_title: "Spot Management"
     )}
  end

  # ── PubSub handlers ────────────────────────────────────────────────

  @impl true
  def handle_info({event, _spot}, socket)
      when event in [:spot_created, :spot_updated, :spot_disabled, :spot_enabled] do
    {:noreply,
     assign(socket,
       spots: Parking.list_spots(),
       next_spot_number: Parking.next_spot_number()
     )}
  end

  # ── Event handlers ─────────────────────────────────────────────────

  @impl true
  def handle_event("show_add_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_add_form: true,
       approved_users: Parking.list_approved_users(),
       next_spot_number: Parking.next_spot_number()
     )}
  end

  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, show_add_form: false)}
  end

  def handle_event("create_spot", %{"owner_id" => owner_id}, socket) do
    case Parking.create_spot(%{owner_id: owner_id}, socket.assigns.current_user) do
      {:ok, spot} ->
        {:noreply,
         socket
         |> assign(show_add_form: false)
         |> put_flash(:info, "Spot ##{spot.spot_number} created successfully.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create spot. Please select an owner.")}
    end
  end

  def handle_event("reassign", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       reassigning_spot_id: String.to_integer(id),
       approved_users: Parking.list_approved_users()
     )}
  end

  def handle_event("cancel_reassign", _params, socket) do
    {:noreply, assign(socket, reassigning_spot_id: nil)}
  end

  def handle_event("save_reassign", %{"spot_id" => spot_id, "owner_id" => owner_id}, socket) do
    spot = Parking.get_spot!(spot_id)

    case Parking.update_spot_owner(spot, %{owner_id: owner_id}, socket.assigns.current_user) do
      {:ok, updated_spot} ->
        {:noreply,
         socket
         |> assign(reassigning_spot_id: nil)
         |> put_flash(:info, "Spot ##{updated_spot.spot_number} reassigned successfully.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to reassign spot.")}
    end
  end

  def handle_event("disable", %{"id" => id}, socket) do
    spot = Parking.get_spot!(id)

    case Parking.disable_spot(spot, socket.assigns.current_user) do
      {:ok, disabled_spot} ->
        {:noreply,
         put_flash(socket, :info, "Spot ##{disabled_spot.spot_number} has been disabled.")}

      {:error, :already_disabled} ->
        {:noreply, put_flash(socket, :error, "Spot is already disabled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disable spot.")}
    end
  end

  def handle_event("enable", %{"id" => id}, socket) do
    spot = Parking.get_spot!(id)

    case Parking.enable_spot(spot, socket.assigns.current_user) do
      {:ok, enabled_spot} ->
        {:noreply,
         put_flash(socket, :info, "Spot ##{enabled_spot.spot_number} has been enabled.")}

      {:error, :not_disabled} ->
        {:noreply, put_flash(socket, :error, "Spot is not disabled.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to enable spot.")}
    end
  end
end
