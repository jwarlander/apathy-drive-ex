defmodule ApathyDrive.Aggression do
  alias ApathyDrive.{Mobile, Monster, Room, TimerManager}
  require Logger

  def react(%Room{} = room, monster_ref) do
    Enum.reduce(room.mobiles, room, fn
      {_ref, %Monster{}}, updated_room ->
        updated_room
      {_ref, %{} = mobile}, updated_room ->
        monster = updated_room.mobiles[monster_ref]
        put_in(updated_room.mobiles[monster_ref], ApathyDrive.Aggression.react(monster, mobile))
    end)
  end

  # Don't attack other monsters
  def react(%Monster{} = monster, %Monster{}), do: monster

  # attack non-monsters if hostile
  def react(%Monster{hostile: true} = monster, %{} = intruder) do
    attack(monster, intruder)
  end

  def react(%Monster{} = monster, %{} = _intruder), do: monster

  def react(%{} = mobile, %{}), do: mobile

  def attack(%{} = attacker, %{ref: ref} = intruder) do
    Logger.info("#{attacker.name} attacking #{intruder.name} (#{inspect ref})")
    time = min(Mobile.attack_interval(attacker), TimerManager.time_remaining(attacker, :auto_attack_timer))

    effect = %{"Aggro" => ref, "stack_key" => {:aggro, ref}, "stack_count" => 1}

    attacker
    |> Systems.Effect.add(effect, 60_000)
    |> TimerManager.send_after({:auto_attack_timer, time, {:execute_auto_attack, attacker.ref}})
  end

end
