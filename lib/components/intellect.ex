defmodule Components.Intellect do
  use GenEvent.Behaviour

  ### Public API
  def value(entity) do
    :gen_event.call(entity, Components.Intellect, :value)
  end

  def value(entity, new_value) do
    ApathyDrive.Entity.notify(entity, {:set_intellect, new_value})
  end

  def serialize(entity) do
    {"Intellect", value(entity)}
  end

  ### GenEvent API
  def init(value) do
    {:ok, value}
  end

  def handle_call(:value, value) do
    {:ok, value, value}
  end

  def handle_event({:set_intellect, value}, _value) do
    {:ok, value }
  end

  def handle_event(_, current_value) do
    {:ok, current_value}
  end
end