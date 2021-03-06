defmodule ApathyDrive.Level do

  def exp_to_next_level(entity) do
    exp_at_level(entity.level + 1) - entity.experience
  end

  def exp_for_level(1), do: 0
  def exp_for_level(lvl) do
    ((1 + :math.pow(lvl - 2, 1.50 + (lvl / 75.0))) * 100000 / 150)
    |> trunc
  end

  def exp_at_level(0), do: nil
  def exp_at_level(level) do
    (1..level)
    |> Enum.reduce(0, fn(lvl, total) ->
         total + exp_for_level(lvl)
       end)
  end

  def exp_reward(level) do
    needed = exp_at_level(level + 1) - exp_at_level(level)

    div(needed, 10 * level)
  end

  def level_at_exp(exp, level \\ 1) do
    if exp_at_level(level) > exp do
      max(level - 1, 1)
    else
      level_at_exp(exp, level + 1)
    end
  end

  def advance(entity) do
    advance(entity, level_at_exp(entity.experience))
  end

  def advance(%{level: current_level, experience: experience} = entity, level) do
    # don't de-level if exp just dips below the current level, prevents bouncing back and
    # forth when spreading essence around
    if (level < current_level) and (experience > (exp_at_level(current_level) * 0.95)) do
      entity
    else
      put_in(entity.level, level)
    end
  end

  def display_exp_table do
    Enum.each(1..50, fn(level) ->
      essence = String.pad_leading("#{exp_at_level(level)}", 8)
      essence_reward = String.pad_leading("#{exp_reward(level)}", 6)
      level = String.pad_leading("#{level}", 2)

      IO.puts "Level: #{level}, Essence Required: #{essence}, Essence per kill: #{essence_reward}"
    end)
  end

end
