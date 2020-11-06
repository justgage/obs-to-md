defmodule Mix.Tasks.DirToHtml do
  use Mix.Task
  require Logger
  @shortdoc "Converts my Zettlekasten"
  def run([from_dir, to_dir, url, website_title]) do
    :ok = Application.start(:combine)
    :ok = Application.start(:rundown)
    :ok = Application.start(:jason)
    :ok = Application.start(:obs_to_md)
    ObsToMd.convert_dir_to_html(Path.expand(from_dir), Path.expand(to_dir), url, website_title)
    Logger.info("DIRECTORY CONVETED SUCCESSFULLY!")
    Process.sleep(100)
    :ok
  end

  def run(args) do
    Logger.error(
      "Wrong number of arguments passed! Should be 3 things: (from_dir, to_dir, url, website_title) but you passed: #{
        inspect(args)
      }"
    )
  end
end
