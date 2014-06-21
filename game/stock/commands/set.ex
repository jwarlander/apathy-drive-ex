defmodule Commands.Set do
  use Systems.Command

  def keywords, do: ["set"]

  def execute(entity, arguments) do

    case arguments do
      ["name", name] ->
        if Entity.has_component?(entity, Components.Name) do
          Components.Player.send_message(entity, ["scroll", "<p>Not so fast, #{Components.Name.value(entity)}, you already have a name.</p>"])
        else
          if Regex.match?(~r/[^a-zA-Z]/, name) do
            Components.Player.send_message(entity, ["scroll", "<p>Your name must consist only of upper or lower case letters.</p>"])
          else
            {first, rest} = String.split_at(name, 1)
            name = "#{String.capitalize(first)}#{rest}"
            Entity.add_component(entity, Components.Name, name)
            Components.Player.send_message(entity, ["scroll", "<p>Your name has been set.</p>"])
          end
        end
      ["name" | args] ->
        Components.Player.send_message(entity, ["scroll", "<p>Your name must consist only of upper or lower case letters.</p>"])
      _ ->
        Components.Player.send_message(entity, ["scroll", "<p>I don't recognize that setting.</p>"])
    end
  end

end
