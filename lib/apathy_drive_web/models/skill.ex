defmodule ApathyDrive.Skill do
  use ApathyDrive.Web, :model
  alias ApathyDrive.Match

  schema "skills" do
    field :name, :string
    field :training_cost_multiplier, :float, default: 1.0
    field :description, :string

    has_many :skills_incompatibilities, ApathyDrive.SkillIncompatibility
    has_many :incompatible_skills, through: [:skills_incompatibilities, :incompatible_skill]
  end

  def create_changeset(name) do
    %__MODULE__{}
    |> cast(%{name: name}, ~w(name))
    |> validate_required(:name)
    |> validate_format(:name, ~r/^[a-zA-Z\d ,\-']+$/)
    |> validate_length(:name, min: 1, max: 20)
    |> unique_constraint(:name)
  end

  def match_by_name(name) do
    __MODULE__
    |> where([skill], not is_nil(skill.name) and skill.name != "")
    |> distinct(true)
    |> select([area], [:id, :name])
    |> ApathyDrive.Repo.all
    |> Match.one(:keyword_starts_with, name)
  end

end