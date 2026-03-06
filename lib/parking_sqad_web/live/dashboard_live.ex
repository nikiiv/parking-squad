defmodule ParkingSqadWeb.DashboardLive do
  use ParkingSqadWeb, :live_view

  alias ParkingSqad.Parking
  alias ParkingSqad.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Month navigation --%>
      <div class="flex items-center justify-between">
        <button phx-click="prev_month" class="btn-secondary !py-1.5 !px-3 text-sm">
          ← Prev
        </button>
        <h1 class="text-xl font-bold text-ctp-mauve">
          <%= calendar_month_name(@current_month) %> <%= elem(@current_month, 0) %>
        </h1>
        <button phx-click="next_month" class="btn-secondary !py-1.5 !px-3 text-sm">
          Next →
        </button>
      </div>

      <%!-- Calendar grid --%>
      <div class="card !p-3">
        <div class="grid grid-cols-7 gap-1">
          <%!-- Day-of-week headers --%>
          <div :for={day_name <- ~w(Mon Tue Wed Thu Fri Sat Sun)} class="text-center text-xs font-semibold text-ctp-subtext0 py-1">
            <%= day_name %>
          </div>

          <%!-- Day cells --%>
          <div
            :for={day <- @calendar_days}
            phx-click={if day.in_month, do: "select_day"}
            phx-value-date={if day.in_month, do: Date.to_iso8601(day.date)}
            class={[
              "relative rounded-lg text-center py-2 px-1 min-h-[3rem] transition-colors text-sm",
              day_cell_classes(day, @selected_date, @today)
            ]}
          >
            <span class={[
              "block font-medium",
              if(!day.in_month, do: "text-ctp-surface2", else: "")
            ]}>
              <%= day.date.day %>
            </span>
            <%= if day.in_month do %>
              <.day_badges summary={Map.get(@month_summary, day.date)} />
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Selected day detail --%>
      <div class="card">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-ctp-text">
            <%= format_selected_date(@selected_date) %>
          </h2>
          <span class={[
            "text-xs font-medium px-2 py-0.5 rounded-full",
            if(Date.compare(@selected_date, @today) == :lt,
              do: "bg-ctp-surface2 text-ctp-subtext0",
              else: "bg-ctp-green/20 text-ctp-green"
            )
          ]}>
            <%= if Date.compare(@selected_date, @today) == :lt, do: "Past", else: if(@selected_date == @today, do: "Today", else: "Upcoming") %>
          </span>
        </div>

        <%= if @day_spots == [] do %>
          <p class="text-ctp-subtext0 text-sm py-4 text-center">
            No parking spots configured yet. An admin needs to add spots first.
          </p>
        <% else %>
          <div class="overflow-hidden rounded-lg border border-ctp-surface1">
            <table class="w-full">
              <thead>
                <tr class="border-b border-ctp-surface1 bg-ctp-surface0/50">
                  <th class="text-left px-3 py-2 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                    Spot
                  </th>
                  <th class="text-left px-3 py-2 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                    Owner
                  </th>
                  <th class="text-left px-3 py-2 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="text-right px-3 py-2 text-xs font-semibold text-ctp-subtext0 uppercase tracking-wider">
                    Action
                  </th>
                </tr>
              </thead>
              <tbody id="day-spots">
                <tr
                  :for={entry <- @day_spots}
                  id={"day-spot-#{entry.spot.id}"}
                  class={[
                    "border-b border-ctp-surface0 last:border-0 transition-colors",
                    if(entry.status == :disabled, do: "opacity-50", else: "hover:bg-ctp-surface0/50")
                  ]}
                >
                  <td class="px-3 py-2.5 text-sm font-medium text-ctp-text">
                    #<%= entry.spot.spot_number %>
                  </td>
                  <td class="px-3 py-2.5 text-sm text-ctp-subtext1">
                    <%= entry.spot.owner.name %>
                    <%= if entry.spot.owner_id == @current_user.id do %>
                      <span class="text-xs text-ctp-mauve">(you)</span>
                    <% end %>
                  </td>
                  <td class="px-3 py-2.5 text-sm">
                    <.spot_status_badge status={entry.status} claimed_by={entry.claimed_by} current_user_id={@current_user.id} />
                  </td>
                  <td class="px-3 py-2.5 text-right">
                    <.spot_action
                      entry={entry}
                      current_user={@current_user}
                      is_past={Date.compare(@selected_date, @today) == :lt}
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Function components ─────────────────────────────────────────────

  defp day_badges(assigns) do
    ~H"""
    <%= if @summary do %>
      <div class="flex justify-center gap-0.5 mt-0.5">
        <span :if={@summary.released > 0} class="inline-block w-1.5 h-1.5 rounded-full bg-ctp-yellow" title={"#{@summary.released} available"}>
        </span>
        <span :if={@summary.claimed > 0} class="inline-block w-1.5 h-1.5 rounded-full bg-ctp-blue" title={"#{@summary.claimed} claimed"}>
        </span>
      </div>
    <% end %>
    """
  end

  attr(:status, :atom, required: true)
  attr(:claimed_by, :map, default: nil)
  attr(:current_user_id, :integer, required: true)

  defp spot_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      status_badge_color(@status)
    ]}>
      <%= case @status do %>
        <% :owner -> %>
          With owner
        <% :released -> %>
          Available
        <% :claimed -> %>
          Claimed by <%= if @claimed_by do %>
            <%= if @claimed_by.id == @current_user_id, do: "you", else: @claimed_by.name %>
          <% end %>
        <% :disabled -> %>
          Disabled
      <% end %>
    </span>
    """
  end

  attr(:entry, :map, required: true)
  attr(:current_user, :map, required: true)
  attr(:is_past, :boolean, required: true)

  defp spot_action(assigns) do
    ~H"""
    <div class="flex gap-1 justify-end">
      <%= if !@is_past && @entry.status != :disabled do %>
        <%= cond do %>
          <% @entry.spot.owner_id == @current_user.id && @entry.status == :owner -> %>
            <button
              phx-click="release_spot"
              phx-value-spot-id={@entry.spot.id}
              class="btn-primary !py-1 !px-2.5 text-xs"
            >
              Release
            </button>
          <% @entry.spot.owner_id == @current_user.id && @entry.status == :released -> %>
            <button
              phx-click="reclaim_spot"
              phx-value-spot-id={@entry.spot.id}
              class="btn-secondary !py-1 !px-2.5 text-xs"
            >
              Reclaim
            </button>
          <% @entry.spot.owner_id == @current_user.id && @entry.status == :claimed -> %>
            <button
              phx-click="reclaim_spot"
              phx-value-spot-id={@entry.spot.id}
              data-confirm={"Reclaim this spot? #{@entry.claimed_by.name}'s reservation will be cancelled."}
              class="btn-danger !py-1 !px-2.5 text-xs"
            >
              Reclaim
            </button>
          <% @entry.status == :released && @entry.spot.owner_id != @current_user.id -> %>
            <button
              phx-click="claim_spot"
              phx-value-spot-id={@entry.spot.id}
              class="btn-success !py-1 !px-2.5 text-xs"
            >
              Claim
            </button>
          <% @entry.status == :claimed && @entry.claimed_by && @entry.claimed_by.id == @current_user.id -> %>
            <button
              phx-click="release_claim"
              phx-value-spot-id={@entry.spot.id}
              class="btn-secondary !py-1 !px-2.5 text-xs"
            >
              Release Claim
            </button>
          <% true -> %>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ── Mount ───────────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Parking.subscribe_reservations()
      Parking.subscribe_spots()
    end

    today = Date.utc_today()
    current_month = {today.year, today.month}

    socket =
      socket
      |> assign(
        today: today,
        current_month: current_month,
        selected_date: today,
        page_title: "Dashboard"
      )
      |> load_month_data()
      |> load_day_data()

    {:ok, socket}
  end

  # ── PubSub handlers ────────────────────────────────────────────────

  @impl true
  def handle_info({:reservation_changed, %{date: date}}, socket) do
    %{current_month: {year, month}, selected_date: selected_date} = socket.assigns

    socket =
      if date.year == year && date.month == month do
        socket = load_month_data(socket)

        if date == selected_date do
          load_day_data(socket)
        else
          socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({event, _spot}, socket)
      when event in [:spot_created, :spot_updated, :spot_disabled, :spot_enabled] do
    socket =
      socket
      |> load_month_data()
      |> load_day_data()

    {:noreply, socket}
  end

  # ── Navigation events ──────────────────────────────────────────────

  @impl true
  def handle_event("prev_month", _params, socket) do
    {year, month} = socket.assigns.current_month
    new_month = shift_month(year, month, -1)

    socket =
      socket
      |> assign(current_month: new_month)
      |> maybe_adjust_selected_date(new_month)
      |> load_month_data()
      |> load_day_data()

    {:noreply, socket}
  end

  def handle_event("next_month", _params, socket) do
    {year, month} = socket.assigns.current_month
    new_month = shift_month(year, month, 1)

    socket =
      socket
      |> assign(current_month: new_month)
      |> maybe_adjust_selected_date(new_month)
      |> load_month_data()
      |> load_day_data()

    {:noreply, socket}
  end

  def handle_event("select_day", %{"date" => date_str}, socket) do
    date = Date.from_iso8601!(date_str)

    socket =
      socket
      |> assign(selected_date: date)
      |> load_day_data()

    {:noreply, socket}
  end

  # ── Spot action events ─────────────────────────────────────────────

  def handle_event("release_spot", %{"spot-id" => spot_id}, socket) do
    spot = Parking.get_spot!(spot_id)
    date = socket.assigns.selected_date
    user = socket.assigns.current_user

    case Parking.release_spot(spot, date, user) do
      {:ok, _reservation} ->
        # Notify all approved users except the owner
        recipients =
          Parking.list_approved_users()
          |> Enum.reject(&(&1.id == user.id))

        Notifications.notify_spot_released(spot, date, recipients)
        {:noreply, put_flash(socket, :info, "Spot ##{spot.spot_number} released for #{date}.")}

      {:error, :spot_disabled} ->
        {:noreply, put_flash(socket, :error, "This spot is currently disabled.")}

      {:error, :not_owner} ->
        {:noreply, put_flash(socket, :error, "You don't own this spot.")}

      {:error, _} ->
        {:noreply,
         put_flash(socket, :error, "Could not release spot. It may already be released.")}
    end
  end

  def handle_event("claim_spot", %{"spot-id" => spot_id}, socket) do
    spot = Parking.get_spot!(spot_id)
    date = socket.assigns.selected_date
    user = socket.assigns.current_user

    case Parking.claim_spot(spot, date, user) do
      {:ok, _reservation} ->
        Notifications.notify_spot_claimed(spot, date, spot.owner, user)
        {:noreply, put_flash(socket, :info, "You claimed spot ##{spot.spot_number} for #{date}.")}

      {:error, :spot_disabled} ->
        {:noreply, put_flash(socket, :error, "This spot is currently disabled.")}

      {:error, :not_available} ->
        {:noreply, put_flash(socket, :error, "This spot is not available for claiming.")}

      {:error, :already_claimed} ->
        {:noreply, put_flash(socket, :error, "This spot was already claimed by someone else.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not claim this spot.")}
    end
  end

  def handle_event("reclaim_spot", %{"spot-id" => spot_id}, socket) do
    spot = Parking.get_spot!(spot_id)
    date = socket.assigns.selected_date
    user = socket.assigns.current_user

    # Get current reservation to find claimer for notification
    day_entry = Enum.find(socket.assigns.day_spots, &(&1.spot.id == spot.id))
    previous_claimer = day_entry && day_entry.claimed_by

    case Parking.reclaim_spot(spot, date, user) do
      :ok ->
        if previous_claimer do
          Notifications.notify_spot_reclaimed(spot, date, previous_claimer)
        end

        {:noreply, put_flash(socket, :info, "Spot ##{spot.spot_number} reclaimed for #{date}.")}

      {:error, :not_owner} ->
        {:noreply, put_flash(socket, :error, "You don't own this spot.")}

      {:error, :already_owned} ->
        {:noreply, put_flash(socket, :error, "This spot is already with you.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not reclaim this spot.")}
    end
  end

  def handle_event("release_claim", %{"spot-id" => spot_id}, socket) do
    spot = Parking.get_spot!(spot_id)
    date = socket.assigns.selected_date
    user = socket.assigns.current_user

    case Parking.release_claim(spot, date, user) do
      {:ok, _reservation} ->
        Notifications.notify_claim_released(spot, date, spot.owner, user)
        {:noreply, put_flash(socket, :info, "Claim on spot ##{spot.spot_number} released.")}

      {:error, :not_claimer} ->
        {:noreply, put_flash(socket, :error, "You did not claim this spot.")}

      {:error, :not_claimed} ->
        {:noreply, put_flash(socket, :error, "This spot is not currently claimed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not release claim.")}
    end
  end

  # ── Private helpers ────────────────────────────────────────────────

  defp load_month_data(socket) do
    {year, month} = socket.assigns.current_month
    summary = Parking.reservation_summary_for_month(year, month)
    calendar_days = build_calendar_days(year, month)
    assign(socket, month_summary: summary, calendar_days: calendar_days)
  end

  defp load_day_data(socket) do
    day_spots = Parking.list_spots_for_date(socket.assigns.selected_date)
    assign(socket, day_spots: day_spots)
  end

  defp shift_month(year, 1, -1), do: {year - 1, 12}
  defp shift_month(year, 12, 1), do: {year + 1, 1}
  defp shift_month(year, month, delta), do: {year, month + delta}

  defp maybe_adjust_selected_date(socket, {year, month}) do
    selected = socket.assigns.selected_date

    if selected.year == year && selected.month == month do
      socket
    else
      # Snap to 1st of the new month
      assign(socket, selected_date: Date.new!(year, month, 1))
    end
  end

  defp build_calendar_days(year, month) do
    first_day = Date.new!(year, month, 1)
    last_day = Date.end_of_month(first_day)

    # Day of week: 1=Mon, 7=Sun
    first_dow = Date.day_of_week(first_day)
    last_dow = Date.day_of_week(last_day)

    # Days to prepend from previous month (Mon start)
    leading_days = first_dow - 1
    # Days to append to fill last week
    trailing_days = if last_dow == 7, do: 0, else: 7 - last_dow

    start_date = Date.add(first_day, -leading_days)
    end_date = Date.add(last_day, trailing_days)

    Date.range(start_date, end_date)
    |> Enum.map(fn date ->
      %{
        date: date,
        in_month: date.month == month && date.year == year
      }
    end)
  end

  defp calendar_month_name({_year, month}) do
    Enum.at(
      ~w(January February March April May June July August September October November December),
      month - 1
    )
  end

  defp format_selected_date(date) do
    day_name =
      case Date.day_of_week(date) do
        1 -> "Monday"
        2 -> "Tuesday"
        3 -> "Wednesday"
        4 -> "Thursday"
        5 -> "Friday"
        6 -> "Saturday"
        7 -> "Sunday"
      end

    month_name =
      Enum.at(
        ~w(January February March April May June July August September October November December),
        date.month - 1
      )

    "#{day_name}, #{month_name} #{date.day}, #{date.year}"
  end

  defp day_cell_classes(day, selected_date, today) do
    cond do
      !day.in_month ->
        "text-ctp-surface2 cursor-default"

      day.date == selected_date ->
        "bg-ctp-mauve text-ctp-crust cursor-pointer font-semibold"

      day.date == today ->
        "ring-2 ring-ctp-mauve ring-inset cursor-pointer hover:bg-ctp-surface1"

      Date.compare(day.date, today) == :lt ->
        "text-ctp-overlay0 cursor-pointer hover:bg-ctp-surface0"

      true ->
        "text-ctp-text cursor-pointer hover:bg-ctp-surface1"
    end
  end

  defp status_badge_color(:owner), do: "bg-ctp-surface2 text-ctp-subtext1"
  defp status_badge_color(:released), do: "bg-ctp-yellow/20 text-ctp-yellow"
  defp status_badge_color(:claimed), do: "bg-ctp-blue/20 text-ctp-blue"
  defp status_badge_color(:disabled), do: "bg-ctp-red/20 text-ctp-red"
end
