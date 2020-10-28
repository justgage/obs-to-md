defmodule Mix.Tasks.DirToHtml do
  use Mix.Task
  require Logger
  @shortdoc "Converts my Zettlekasten"
  def run([from_dir, to_dir]) do
    :ok = Application.start(:combine)
    :ok = Application.start(:rundown)
    :ok = Application.start(:obs_to_md)
    ObsToMd.convert_dir_to_html(from_dir, to_dir)
    Logger.info("DIRECTORY CONVETED SUCCESSFULLY!")
    Process.sleep(100)
    :ok
  end
end
