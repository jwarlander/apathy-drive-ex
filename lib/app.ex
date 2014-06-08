defmodule ApathyDrive do

  require Weber.Templates.ViewsLoader

  def start(_type, _args) do

    :crypto.start
    :bcrypt.start
    :random.seed(:erlang.now)

    Players.start_link
    Races.start_link
    Characters.start_link
    Monsters.start_link
    MonsterTemplates.start_link
    Items.start_link
    ItemTemplates.start_link
    Rooms.start_link
    Exits.start_link
    Components.start_link
    Help.start_link
    Repo.start_link
    Commands.start_link
    Abilities.start_link
    Skills.start_link

    get_file_list(["game/**/*.ex"])
    |> Enum.each fn(file) ->
      IO.puts "Compiled #{file}"
      Code.load_file(file)
    end
    # Set resources
    Weber.Templates.ViewsLoader.set_up_resources(File.cwd!)
    # compile all views
    Weber.Templates.ViewsLoader.compile_views(File.cwd!)

    if Mix.env != :test do
      IO.puts "Loading Entities..."
      Entities.load!
      IO.puts "Done!"
    end

    Systems.LairSpawning.initialize
    Systems.HPRegen.initialize

    # start weber application
    Weber.run_weber

  end

  def stop(_state) do
    :ok
  end

  defp get_file_list(path, file_index \\ []) when is_binary(path) do
    get_file_list([path], file_index)
  end

  defp get_file_list([], file_index) do
    file_index
  end

  defp get_file_list([path | paths], file_index) do
    updated_file_index = Enum.reduce Path.wildcard(path), file_index, fn(file_path, index)->
      {:ok, file_info} = File.stat(file_path)
      if file_info.type == :directory || Enum.member?(index, file_path) do
        index
      else
        [file_path | index]
      end
    end

    get_file_list(paths, updated_file_index)
  end

end
