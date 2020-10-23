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
  def convert_dir_to_dir(incoming_dir, outcoming_dir) do
    File.mkdir(outcoming_dir)

    incoming_dir
    |> files_to_md
    |> pmap(fn
      {path, :binary} ->
        Logger.warn("Copying #{path}")
        binary_filename = path |> String.split("/") |> List.last()

        File.cp!(
          (incoming_dir <> "/" <> path) |> String.replace(" ", "\ "),
          outcoming_dir <> "/" <> binary_filename
        )

      {file_name, contents} ->
        File.write!(outcoming_dir <> "/" <> file_name, contents)
    end)
  end

  def files_to_md(dir) do
    parse_files(dir)
    |> Enum.flat_map(fn
      {path, :binary} ->
        [{path, :binary}]

      {key, parsed} ->
        md_string = parsed_to_md(parsed)

        [
          # {key <> ".html", md_string |> String.split("\n") |> Earmark.as_html!()},
          {key,
           """
           # #{key |> String.split(".") |> List.first()}

           #{md_string}
           """}
        ]
    end)
    |> Map.new()
  end

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
        path ->
          file_name = path |> String.split("/") |> List.last()

          if String.contains?(file_name, ".md") do
            Logger.info("Parsing..." <> path)
            contents = File.read!(path)
            {file_name, convert(contents)}
          else
            {path, :binary}
          end
      end)
      |> Map.new()

    new_files =
      parsed
      |> Enum.map(fn
        {filename, :binary} ->
          {filename, :binary}

        {filename, file} ->
          file =
            Map.update(file, :files, [], fn sub_files ->
              sub_files
              |> Enum.flat_map(fn sub_file ->
                name = "#{sub_file.file_name}.#{sub_file.extn}"

                case parsed[name] do
                  nil -> []
                  file -> [{name, file}]
                end
              end)
              |> Map.new()
            end)

          {filename, file}
      end)

    File.cd!(current_dir)
    new_files
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

  def parsed_to_md(:binary) do
    :binary
  end

  def parsed_to_md(parsed) do
    file =
      parsed.parts
      |> Enum.map(fn
        {:text, text} ->
          text

        {:tag, %{file: %{extn: extn, file_name: file_name}, title: title}} ->
          "[#{title}](#{file_name}.#{extn})"

        {:unmatched, text} ->
          text

        {:embeded_tag, %{file: %{extn: extn, file_name: file_name}, title: title}} ->
          case parsed.files do
            %{} ->
              case parsed.files["#{file_name}.#{extn}"] do
                nil ->
                  "![#{title}](#{file_name}.#{extn})"

                sub_file ->
                  """
                  ---
                  ## [#{title}](#{file_name}.#{extn}) ⤴
                  #{parsed_to_md(sub_file)}
                  ---
                  """
              end

            _ ->
              "![#{title}](#{file_name}.#{extn})"
          end
      end)
      |> Enum.join()

    file
  end

  def markdown do
    many(choice([embeded_tag(), tag(), unmatched_tag(), between_stuff()]))
  end

  @spec tag_text :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def tag_text do
    many1(none_of(char(), ~s(.|*/\<>:][) |> String.codepoints()))
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
  @spec between_stuff :: (Combine.ParserState.t() -> Combine.ParserState.t())
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
