defmodule ObsToMd do
  use Combine
  require Logger

  @moduledoc """
  Documentation for `ObsToMd`.
  """

  @url "https://justgage.github.io/"

  @audio_extns ~w[mp3]

  @letters ?A..?Z |> Enum.map(&to_string([&1]))

  @private_triggers [
    "[[Day One]]",
    "Dayone",
    "dayone",
    "Piano",
    "Mayne",
    "piano",
    "Hoss",
    "BJ",
    "[[church]]",
    "password",
    "#private",
    "Teamchat",
    "Jessica",
    "Podium",
    "Darvil",
    "Lindy",
    "Koda",
    "[[journal]]"
  ]

  @doc """
  Hello world.

  ## Examples

      iex> ObsToMd.hello()
      :world

  """
  def convert_dir_to_md(incoming_dir, outcoming_dir) do
    File.mkdir(outcoming_dir)

    incoming_dir
    |> files_to_md()
    |> Enum.map(fn
      {path, :binary} ->
        binary_filename = path |> String.split("/") |> List.last()

        File.cp!(
          (incoming_dir <> "/" <> path) |> String.replace(" ", "\ "),
          outcoming_dir <> "/" <> escape_filename(binary_filename)
        )

      {file_name, contents} ->
        File.write!(outcoming_dir <> "/" <> escape_filename(file_name), contents)
    end)
  end

  def convert_dir_to_html(incoming_dir, outcoming_dir) do
    File.mkdir(outcoming_dir)

    incoming_dir
    |> files_to_html()
    |> Enum.map(fn
      {path, :binary} ->
        binary_filename = path |> String.split("/") |> List.last()

        File.cp!(
          (incoming_dir <> "/" <> path) |> String.replace(" ", "\ "),
          outcoming_dir <>
            "/" <> escape_filename(binary_filename)
        )

      {file_name, contents} ->
        File.write!(
          (outcoming_dir <> "/" <> escape_filename(file_name)) |> String.replace(".md", ".html"),
          contents
        )
    end)
  end

  def files_to_html(dir) do
    dir
    |> files_to_md()
    |> pmap(fn
      {filename, str} when is_binary(str) ->
        {:ok, contents} = Rundown.convert(@url, str)

        {filename,
         EEx.eval_file("/Users/justgage/code/obs_to_md/lib/template.html.eex",
           content: contents,
           title: filename |> String.replace(".md", "")
         )}

      {filename, other} ->
        {filename, other}
    end)
  end

  def files_to_md(dir) do
    files =
      parse_files(dir)
      |> Enum.flat_map(fn
        {path, :binary} ->
          [{path, :binary}]

        {key, parsed} ->
          md_string = parsed_to_md(parsed)

          first_line = md_string |> String.split("\n") |> List.first() || ""

          md_string =
            if String.jaro_distance(key |> String.downcase(), first_line |> String.downcase()) >
                 0.7 do
              md_string
            else
              """
              # #{key |> String.split(".") |> List.first()}

              #{md_string}
              """
            end

          [
            {key, md_string}
          ]
      end)

    slipbox_contents =
      files
      |> Enum.flat_map(fn {name, file_contents} ->
        if is_binary(file_contents) &&
             String.contains?(
               file_contents,
               "404"
             ) do
          []
        else
          if String.contains?(name, [".md"]) do
            [
              {name,
               "[#{name |> String.replace(".md", "")}](#{
                 escape_filename(name) |> String.replace(".md", "")
               })"}
            ]
          else
            []
          end
        end
      end)
      |> Enum.group_by(
        fn {name, _} ->
          first_letter = String.upcase(String.first(name))

          if first_letter in @letters do
            first_letter
          else
            "~"
          end
        end,
        &elem(&1, 1)
      )
      |> Enum.sort()
      |> Enum.map(fn {first_letter, values} ->
        """

        ## #{first_letter}
        #{values |> Enum.join(" | ")}
        """
      end)
      |> Enum.join("\n")

    files =
      files ++
        [
          {"slipbox.md",
           """
           # Slipbox

           #{slipbox_contents}
           """}
        ]

    Map.new(files)
  end

  @spec add_backlinks(any) :: [any]
  def add_backlinks(files) do
    backlinks =
      files
      |> Enum.flat_map(fn
        {_k, file = %{}} ->
          # Links
          file[:files]

        _ ->
          []
      end)
      |> Enum.flat_map(fn
        {file_pointed_to, file_pointing} ->
          file_pointing.files
          |> Enum.map(fn %{extn: extn, file_name: name} ->
            # Flip the keys so it's pointing backward
            {"#{name}.#{extn}", file_pointed_to}
          end)
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    files
    |> Enum.map(fn
      {name, file = %{}} ->
        {name, Map.put(file, :backlinks, (backlinks[name] || []) |> Enum.uniq())}

      k ->
        k
    end)
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
            contents = File.read!(Path.expand(path))

            if String.contains?(file_name, @private_triggers) ||
                 (String.contains?(contents, @private_triggers) &&
                    !String.contains?(contents, "#public")) do
              {file_name, :private}
            else
              {file_name, convert(contents)}
            end
          else
            {path, :binary}
          end
      end)
      |> Enum.filter(fn
        {_, :private} -> false
        _ -> true
      end)
      |> Map.new()

    {new_files, stubs} =
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
                  nil ->
                    [
                      {name,
                       %{
                         stub: true,
                         files: [],
                         parts: [text: "*this file hasn't been written, it's a stub*"]
                       }}
                    ]

                  file ->
                    [{name, file}]
                end
              end)
              |> Map.new()
            end)

          {filename, file}
      end)
      |> Enum.map(fn
        {filename, file = %{}} ->
          {{filename, file},
           Enum.filter(file.files, fn
             {_item, %{stub: true}} -> true
             _ -> false
           end)}

        k ->
          {k, []}
      end)
      |> Enum.unzip()

    new_files =
      (new_files ++ Enum.flat_map(stubs, & &1)) |> Enum.uniq_by(&escape_filename(elem(&1, 0)))

    File.cd!(current_dir)
    new_files |> add_backlinks()
  end

  def find_files(dir) do
    current_dir = File.cwd!()

    File.cd!(dir)

    {files_found_str, 0} =
      System.cmd("fd", ~w[-t=f -e=.md -e=.gif -e=.png -e=.jpg -e=.mp3 -e=.md])

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
        {:embeded_tag, %{file: file = %{extn: _, file_name: _}, title: _}} ->
          [file]

        {:tag, %{file: file = %{extn: _, file_name: _}, title: _}} ->
          [file]

        _ ->
          []
      end)

    %{
      parts: parts,
      files: files
    }
  end

  @spec escape_filename(binary) :: binary
  def escape_filename(filename) do
    if String.length(filename) > 255 do
      raise "Filename too big!: " <> filename
    end

    String.downcase(filename)
    |> String.replace(" ", "-")
    |> String.replace("(", "")
    |> String.replace(")", "")
  end

  @spec parsed_to_md(:binary | nil | %{parts: any}) :: :binary | binary
  def parsed_to_md(:binary) do
    :binary
  end

  def parsed_to_md(parsed) do
    parsed_as_markdown =
      parsed.parts
      |> Enum.map(fn
        {:text, text} ->
          text

        {:tag, %{file: %{extn: _extn, file_name: file_name}, title: title}} ->
          # "[#{title}](#{escape_filename("#{escape_filename("#{file_name}.#{extn}")}")})"
          "[#{title}](#{escape_filename("#{escape_filename("#{file_name}")}")})"

        {:unmatched, text} ->
          text

        {:image, %{file: %{extn: extn, file_name: file_name}, title: title}} ->
          "![#{title}](#{escape_filename("#{file_name}.#{extn}")})"

        {:audio, %{file: %{extn: extn, file_name: file_name}, title: _title}} ->
          """
          <audio controls>
            <source src="#{file_name}.#{extn}" type="audio/#{extn}">
          Your browser does not support the audio element.
          </audio>
          """

        {:embeded_tag, %{file: %{extn: extn, file_name: file_name}, title: title}} ->
          case parsed.files do
            %{} ->
              case parsed.files["#{file_name}.#{extn}"] do
                nil ->
                  "*See: [#{title} ⤴](#{escape_filename("#{file_name}")})*\n"

                sub_file ->
                  """
                  # #{title} [🔖](#{escape_filename("#{file_name}")})

                  #{parsed_to_md(sub_file)}
                  ---
                  """
              end
          end
      end)
      |> Enum.join()

    parsed_as_markdown =
      if String.trim(parsed_as_markdown) == "" do
        "*This file is a stub, it hasn't been written yet*"
      else
        parsed_as_markdown
      end

    if parsed[:backlinks] && parsed[:backlinks] != [] do
      """
      #{parsed_as_markdown}

      ---
      ***Backlinks***:

      #{
        parsed.backlinks
        |> Enum.sort()
        |> Enum.map(fn name ->
          file_name = name |> String.replace(".md", "")
          "- [#{file_name}](#{escape_filename(file_name)})\n"
        end)
      }
      """
    else
      parsed_as_markdown
    end
  end

  @spec markdown :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def markdown do
    many(choice([embeded_tag(), tag(), unmatched_tag(), between_stuff()]))
  end

  @spec tag_text :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def tag_text do
    many1(none_of(char(), ~s(.|*/\<>:][) |> String.codepoints()))
    |> map(fn list -> Enum.join(list) end)
  end

  @spec filename :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def filename do
    either(
      sequence([
        tag_text(),
        char(".") |> ignore(),
        choice([
          string("gif"),
          string("png"),
          string("jpg"),
          string("mp3"),
          string("md")
        ])
      ])
      |> map(fn [file_name, extn] -> %{file_name: file_name, extn: extn} end),
      many1(either(tag_text(), char(".")))
      |> map(fn file_name -> %{file_name: Enum.join(file_name), extn: "md"} end)
    )
  end

  @spec tag :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def tag do
    either(
      title_tag(),
      plain_tag()
    )
  end

  @spec plain_tag :: (Combine.ParserState.t() -> Combine.ParserState.t())
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

  @spec title_tag :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def title_tag do
    sequence([
      string("[[") |> ignore(),
      filename(),
      char("|") |> ignore(),
      tag_text(),
      string("]]") |> ignore()
    ])
    |> map(fn [filename, title] ->
      {:tag, %{file: filename, title: title}}
    end)
  end

  @spec embeded_tag :: (Combine.ParserState.t() -> Combine.ParserState.t())
  def embeded_tag do
    pair_right(char("!"), tag())
    |> map(fn {:tag, tag = %{file: %{extn: extn}}} ->
      cond do
        extn == "md" -> {:embeded_tag, tag}
        extn in @audio_extns -> {:audio, tag}
        true -> {:image, tag}
      end
    end)
  end

  @spec unmatched_tag :: (Combine.ParserState.t() -> Combine.ParserState.t())
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
