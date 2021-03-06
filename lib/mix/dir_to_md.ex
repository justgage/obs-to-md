defmodule Mix.Tasks.DirToMd do
  use Mix.Task
  require Logger
  @shortdoc "Converts my Zettlekasten"
  def run([from_dir, to_dir]) do
    {:ok, _} = Application.ensure_all_started(:obs_to_md)
    ObsToMd.convert_dir_to_md(Path.expand(from_dir), Path.expand(to_dir))
    Logger.info("DIRECTORY CONVERTED SUCCESSFULLY!")
    Process.sleep(100)
    :ok
  end

  def run(args) do
    Logger.error(
      "Wrong number of arguments passed! Should be 3 things: (from_dir, to_dir) but you passed: #{
        inspect(args)
      }"
    )
  end
end
