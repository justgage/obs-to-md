defmodule ObsToMd do
  use Combine
  require Logger

  @moduledoc """
  Documentation for `ObsToMd`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ObsToMd.hello()
      :world

  """
  def parse_files(dir) do
    files = find_files(dir)

    current_dir = File.cwd!()
    File.cd!(dir)

    parsed =
      files
      |> Enum.map(&(elem(&1, 1) |> Enum.map(fn %{path: path} -> path end)))
      |> Enum.map(fn
        paths -> paths |> Enum.sort() |> List.first()
      end)
      |> pmap(fn
        maybe_md ->
          file_name = maybe_md |> String.split("/") |> List.last()

          if String.contains?(maybe_md, ".md") do
            Logger.info("Parsing..." <> maybe_md)
            contents = File.read!(maybe_md)
            {file_name, convert(contents |> IO.inspect(label: "thingy"))}
          else
            {file_name, :binary}
          end
      end)

    File.cd!(current_dir)
    parsed |> Map.new()
  end

  def find_files(dir) do
    current_dir = File.cwd!()

    File.cd!(dir)

    {files_found_str, 0} = System.cmd("fd", ~w[-t=f -e=.md -e=.png -e=.jpg -e=.mp3 -e=.md])

    files =
      files_found_str
      |> String.split("\n")
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn file_path ->
        %{name: file_path |> String.split("/") |> List.last(), path: file_path}
      end)
      |> Enum.group_by(& &1.name)

    File.cd!(current_dir)

    files
  end

  def convert(input) do
    parts = Combine.parse(input, markdown()) |> Enum.flat_map(& &1)

    files =
      Enum.flat_map(parts, fn
        {:tag, %{file: file = %{extn: _, file_name: _}, title: _}} -> [file]
        _ -> []
      end)

    %{
      parts: parts,
      files: files
    }
  end

  def markdown do
    many(choice([embeded_tag(), tag(), unmatched_tag(), between_stuff()]))
  end

  @spec tag_text :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def tag_text do
    many1(none_of(char(), ~s(.|* " / \ < > : ? ] [) |> String.codepoints()))
    |> map(fn list -> Enum.join(list) end)
  end

  def filename do
    either(
      sequence([
        tag_text(),
        char(".") |> skip(),
        choice([
          string("png"),
          string("jpg"),
          string("mp3"),
          string("md")
        ])
      ])
      |> map(fn [file_name, extn] -> %{file_name: file_name, extn: extn} end),
      many(either(tag_text(), char(".")))
      |> map(fn file_name -> %{file_name: Enum.join(file_name), extn: "md"} end)
    )
  end

  def tag do
    either(
      title_tag(),
      plain_tag()
    )
  end

  def plain_tag do
    between(
      string("[["),
      filename()
      |> map(fn file = %{file_name: title} ->
        {:tag, %{file: file, title: title}}
      end),
      string("]]")
    )
  end

  def title_tag do
    sequence([
      string("[[") |> skip(),
      filename(),
      char("|") |> skip(),
      tag_text(),
      string("]]") |> skip()
    ])
    |> map(fn [filename, title] ->
      {:tag, %{file: filename, title: title}}
    end)
  end

  def embeded_tag do
    pair_right(char("!"), tag()) |> map(fn {:tag, tag} -> {:embeded_tag, tag} end)
  end

  def unmatched_tag do
    either(char("["), char("!")) |> map(&{:unmatched, &1})
  end

  # Stuff that's not a tag!
  def between_stuff do
    many1(none_of(char(), "![" |> String.codepoints()))
    |> map(fn list -> {:text, Enum.join(list)} end)
  end

  def pmap(collection, func) do
    collection
    |> Enum.map(&Task.async(fn -> func.(&1) end))
    |> Enum.map(&Task.await/1)
  end
end
