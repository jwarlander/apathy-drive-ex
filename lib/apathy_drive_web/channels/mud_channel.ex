defmodule ApathyDriveWeb.MUDChannel do
  use ApathyDrive.Web, :channel
  alias ApathyDrive.{Character, Mobile, Presence, RoomServer}

  def join("mud:play", %{"character" => token}, socket) do
    case Phoenix.Token.verify(socket, "character", token, max_age: 1209600) do
      {:ok, character_id} ->
        case Repo.get!(Character, character_id) do
          nil ->
            {:error, %{reason: "unauthorized"}}
          %Character{name: nil} -> # Character has been reset, probably due to a game wipe
            {:error, %{reason: "unauthorized"}}
          %Character{room_id: room_id} = character ->
            character =
              room_id
              |> RoomServer.find
              |> RoomServer.character_connected(character, self())

            socket =
              socket
              |> assign(:room_id, room_id)
              |> assign(:character, character.id)
              |> assign(:power, Mobile.power_at_level(character, character.level))
              |> assign(:level, character.level)
              |> assign(:monster_ref, character.ref)

              ApathyDrive.PubSub.subscribe("spirits:online")
              ApathyDrive.PubSub.subscribe("chat:gossip")
              ApathyDrive.PubSub.subscribe("chat:#{String.downcase(character.class)}")

            send(self(), :after_join)

            {:ok, socket}
        end
      {:error, _} ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    socket.assigns[:room_id]
    |> RoomServer.find
    |> RoomServer.execute_command(socket.assigns[:monster_ref], "l", [])

    {:noreply, socket}
  end

  def handle_info({:update_ref, ref}, socket) do
    socket = assign(socket, :monster_ref, ref)

    {:noreply, socket}
  end

  def handle_info({:disable_element, elem}, socket) do
    Phoenix.Channel.push socket, "disable", %{:html => elem}

    {:noreply, socket}
  end

  def handle_info({:update_character, %{room_id: room_id, power: power, level: level}}, socket) do
    socket =
      socket
      |> assign(:room_id, room_id)
      |> assign(:power, power)
      |> assign(:level, level)

    update_room(socket)

    {:noreply, socket}
  end

  def handle_info({:scroll, %{} = data}, socket) do
    if socket.assigns[:spirit_id] in Map.keys(data) do
      send_scroll(socket, data[socket.assigns[:monster_ref]])
    else
      send_scroll(socket, data[:other])
    end

    {:noreply, socket}
  end

  def handle_info({:scroll, html}, socket) do
    send_scroll(socket, html)

    {:noreply, socket}
  end

  def handle_info({:focus_element, elem}, socket) do
    Phoenix.Channel.push socket, "focus", %{:html => elem}

    {:noreply, socket}
  end

  def handle_info(:up, socket) do
    Phoenix.Channel.push socket, "up", %{}

    {:noreply, socket}
  end

  def handle_info({:update_prompt, html}, socket) do
    Phoenix.Channel.push socket, "update prompt", %{:html => html}

    {:noreply, socket}
  end

  def handle_info({:update_room_essence, essence}, socket) do
    Phoenix.Channel.push socket, "update room essence", essence

    {:noreply, socket}
  end

  def handle_info(:go_home, socket) do
    Phoenix.Channel.push socket, "redirect", %{:url => "/"}

    {:noreply, socket}
  end

  def handle_info({:open_tab, path}, socket) do
    Phoenix.Channel.push socket, "open tab", %{:url => path}

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: %{joins: joins, leaves: leaves}}, socket) do
    (Presence.metas(joins) -- Presence.metas("spirits:online"))
    |> Enum.each(fn %{name: name} ->
         Phoenix.Channel.push socket, "scroll", %{:html => "<p>#{name} just entered the Realm.</p>"}
       end)

    leaves
    |> Presence.metas
    |> Enum.each(fn %{name: name} ->
         Phoenix.Channel.push socket, "scroll", %{:html => "<p>#{name} just left the Realm.</p>"}
       end)

    {:noreply, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    Phoenix.Channel.push socket, event, payload

    {:noreply, socket}
  end

  def handle_in("command", %{}, socket) do

    socket.assigns[:room_id]
    |> RoomServer.find
    |> RoomServer.execute_command(socket.assigns[:monster_ref], "l", [])

    {:noreply, socket}
  end

  def handle_in("command", message, socket) do
    case String.split(message) do
      [command | arguments] ->
        socket.assigns[:room_id]
        |> RoomServer.find
        |> RoomServer.execute_command(socket.assigns[:monster_ref], command, arguments)
      [] ->
        socket.assigns[:room_id]
        |> RoomServer.find
        |> RoomServer.execute_command(socket.assigns[:monster_ref], "l", [])
    end

    {:noreply, socket}
  end

  def handle_in("map", "request_room_id", socket) do
    update_room(socket)
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (mud:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # This is invoked every time a notification is being broadcast
  # to the client. The default implementation is just to push it
  # downstream but one could filter or change the event.
  def handle_out(event, payload, socket) do
    push socket, event, payload
    {:noreply, socket}
  end

  defp update_room(socket) do
    Phoenix.Channel.push socket, "update_room", %{room_id: socket.assigns[:room_id], power: socket.assigns[:power], level: socket.assigns[:level]}
  end

  defp send_scroll(socket, html) do
    Phoenix.Channel.push socket, "scroll", %{:html => html}
  end

end
