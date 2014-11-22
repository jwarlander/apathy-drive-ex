defmodule Systems.Room do
  use Systems.Reload
  import Utility

  def display_room_in_scroll(character, room_pid) do
    send_message(character, "scroll", long_room_html(character, room_pid))
  end

  def long_room_html(character, room) do
    directions = room |> exit_directions |> exit_directions_html
    "<div class='room'>#{name_html(room)}#{description_html(room)}#{shop(room)}#{items_html(room)}#{entities_html(character, room)}#{directions}</div>"
  end

  def short_room_html(room) do
    directions = room |> exit_directions |> exit_directions_html
    "<div class='room'>#{name_html(room)}#{directions}</div>"
  end

  def shop(room) do
    case Entity.has_component?(room, Components.Shop) || Entity.has_component?(room, Components.Trainer) do
      true  -> "<p><br><em>Type 'list' to see a list of goods and services sold here.</em><br><br></p>"
      false -> ""
    end
  end

  def get_current_room(entity) do
    Parent.of(entity)
  end

  def exit_directions(room) do
    exits(room)
    |> Enum.map(fn(room_exit) ->
         :"Elixir.Systems.Exits.#{room_exit["kind"]}".display_direction(room, room_exit)
       end)
  end

  def exit_directions_html([]) do
    "<div class='exits'>Obvious exits: NONE</div>"
  end

  def exit_directions_html(directions) do
    "<div class='exits'>Obvious exits: #{Enum.join(directions, ", ")}</div>"
  end

  def exits(room) do
    Components.Exits.value(room)
  end

  def description(room) do
    Components.Description.get_description(room)
  end

  def description_html(room) do
    "<div class='description'>#{description(room)}</div>"
  end

  def name(room) do
    Components.Name.get_name(room)
  end

  def name_html(room) do
    "<div class='title'>#{name(room)}</div>"
  end

  def items(room) do
    Components.Items.get_items(room) |> Enum.map(&(Components.Name.value(&1)))
  end

  def items_html(room) do
    items = items(room)

    case Enum.count(items) do
      0 ->
        ""
      _ ->
        "<div class='items'>You notice #{Enum.join(items(room), ", ")} here.</div>"
    end
  end

  def entities(entity, room) do
    monsters_in_room(room) |> Enum.reject(&(entity == &1))
  end

  def entities_html(character, room) do
    entities = entities(character, room)
    case Enum.count(entities) do
      0 ->
        ""
      _ ->
        entities = entities
                   |> Enum.map(fn(entity) ->
                        cond do
                          Components.Alignment.evil?(entity) ->
                            "<span class='magenta'>#{Components.Name.value(entity)}</span>"
                          Components.Alignment.good?(entity) ->
                            "<span class='grey'>#{Components.Name.value(entity)}</span>"
                          Components.Alignment.neutral?(entity) ->
                            "<span class='dark-cyan'>#{Components.Name.value(entity)}</span>"
                        end
                      end)
                   |> Enum.join("<span class='magenta'>, </span>")
        "<div class='entities'><span class='dark-magenta'>Also here:</span> #{entities}<span class='dark-magenta'>.</span></div>"
    end
  end

  def move(spirit, monster, direction) do
    Systems.Exit.move(spirit, monster, direction)
  end

  def living_in_room(room) do
    characters = characters_in_room(room) |> Enum.reject(&(Components.Spirit.value(&1)))
    Enum.concat(monsters_in_room(room), characters)
  end

  def living_in_room(entities, room) do
    Enum.filter(entities, &(room == Parent.of(&1)))
  end

  def characters_in_room(room) do
    Characters.online
    |> living_in_room(room)
  end

  def monsters_in_room(room) do
    Components.Monsters.get_monsters(room)
  end

  def characters_in_room(room, character_to_exclude) do
    characters_in_room(room) |> Enum.reject(&(&1 == character_to_exclude))
  end

end
