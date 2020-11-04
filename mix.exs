defmodule ObsToMd.MixProject do
  use Mix.Project

  def project do
    [
      app: :obs_to_md,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:combine, "~> 0.10.0"},
      {:rundown, "~> 0.1.0"},
      {:jason, "~> 1.2"}

      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
