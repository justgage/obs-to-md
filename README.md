# ObsToMd

This converts Obsidian style Markdown into a Website (or markdown)

## Command Line

Just do a `git clone` on the repo

then go into the directory

```
mix deps.get
```

Then run this command to convert an Obsidian folder into a static website:

```
mix dir_to_html "~/My-Obsidian-Vault" "~/website_folder" "http://my-website.github.io" "My Website Name"
```

## As library

This is yet un-published, but you can look at the `lib/obs_to_md.ex` file.

<!-- If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `obs_to_md` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:obs_to_md, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/obs_to_md](https://hexdocs.pm/obs_to_md).
 -->
