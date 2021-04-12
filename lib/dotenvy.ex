defmodule Dotenvy do
  @moduledoc """
  `Dotenvy` is an Elixir implementation of the original [dotenv](https://github.com/bkeepers/dotenv) package.

  It assists in setting environment variables in ways that are compatible with both
  mix releases and with runtime configuration using conventions that should be familiar
  to developers coming from other languages. Conveniences for reading the variables
  and converting thier values are included (See `Dotenvy/env!/2`, `Dotenvy.env/3`,
  and `Dotenvy.Transformer.to/2`).

  Unlike other configuration helpers, `Dotenvy` enforces no convention for the naming
  of your files: you may name your configuration files whatever you wish.  `.env` and
  its variants is a common choice, but `Dotenvy` does not have opinions.  You must
  only pass file paths as arguments to the `Dotenvy.source/2` or `Dotenvy.source!/2`
  functions.

  ## Usage Suggestion

  `Dotenvy` is designed to help help set up your application _at runtime_. However,
  saying "at runtime" isn't specific enough: an application's configuration must be
  bootstrapped _before_ it can actually start.  Although there are other places
  where `Dotenvy` may prove useful, it was designed with the `config/runtime.exs`
  in mind: that's where it helps make the hand-off from system environment variables
  to the application configuration in the cleanest, most declarative way possible.

  ### `.env` for environment-specific config

  It is possible to use _only_ a `config.exs` and and `runtime.exs` file to configure
  many Elixir applications: let the `.env` files handle any differences between environments.
  Consider the following setup:

  #### `config/config.exs`

      # compile-time config
      import Config

      config :myapp,
        ecto_repos: [MyApp.Repo]

      config :myapp, MyApp.Repo,
        migration_timestamps: [
          type: :utc_datetime,
          inserted_at: :created_at
        ]

  #### `config/runtime.exs`

      import Config
      import Dotenvy

      source([".env", ".env.\#{config_env()}"])

      config :myapp, MyApp.Repo,
        database: env!("DATABASE", :string),
        username: env!("USERNAME", :string),
        password: env!("PASSWORD", :string),
        hostname: env!("HOSTNAME", :string),
        pool_size: env!("POOL_SIZE", :integer),
        adapter: env("ADAPTER", :module, Ecto.Adapters.Postgres),
        pool: env!("POOL", :module?)

  #### `.env`

        DATABASE=myapp_dev
        USERNAME=myuser
        PASSWORD=mypassword
        HOSTNAME=localhost
        POOL_SIZE=10
        POOL=


  #### `.env.test`

        DATABASE=myapp_test
        USERNAME=myuser
        PASSWORD=mypassword
        HOSTNAME=localhost
        POOL_SIZE=10
        POOL=Ecto.Adapters.SQL.Sandbox

  The above setup would expect `.env` to be in the `.gitignore`.  The above example
  demonstrates developer settings appropriate for local development, but a production
  deployment would only differ in its _values_: the shape of the file would be the same.

  The `.env.test` file is loaded when running tests, so its values override any of the
  values set in the `.env`.

  By using `Dotenvy.env!/2`, there is a strong contract with the environment: the
  system running this app _must_ have the designated environment variables set somehow,
  otherwise this app will not start (and a specific error will be raised).

  Using the nil-able variants of the type-casting (those ending with `?`) is an easy
  way to defer to default values: `env!("POOL", :module?)` requires that the `POOL`
  variable is set, but it will return a `nil` if the value is an empty string.
  See `Dotenvy.Transformer` for more details.


  """
  import Dotenvy.Transformer

  require Logger

  @default_parser Dotenvy.Parser

  @doc """
  A parser implementation should receive the `contents` read from a file,
  a map of `vars` (with string keys, as would come from `System.get_env/0`),
  and a keyword list of `opts`.
  """
  @callback parse(contents :: binary(), vars :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, any()}
  @doc """
  Attempts to read the given system environment `variable`; if it exists, its
  value is converted to the given `type`. If the variable is not found, the
  provided `default` is returned.

  The `default` value will **not** be converted: it will be returned as-is.
  This allows greater control of the output.

  Although this relies on `System.fetch_env/1`, it may still raise an error
  if an unsupported `type` is provided.

  ## Examples

      iex> env("PORT", :integer, 5432)
      5433
      iex> env("NOT_SET", :boolean, %{not: "converted"})
      %{not: "converted"}
  """
  @spec env(variable :: binary(), type :: atom(), default :: any()) :: any()
  def env(variable, type, default \\ nil) do
    variable
    |> System.fetch_env()
    |> case do
      :error -> default
      {:ok, value} -> to(value, type)
    end
  end

  @doc """
  Reads the given system environment `variable` and converts its value to the given
  `type`. This relies on `System.fetch_env!/1` so it will raise if a variable is
  not set.

  ## Examples

      iex> env!("PORT", :integer)
      5432
      iex> env!("ENABLED", :boolean)
      true
  """
  @spec env!(variable :: binary(), type :: atom()) :: any()
  def env!(variable, type) do
    variable
    |> System.fetch_env!()
    |> to(type)
  end

  @doc """
  Like Bash's `source` command, this loads the given file(s) and sets the corresponding
  system environment variables using a side effect function (`&System.put_env/1` by default).

  Files are processed in the order they are given. Values parsed from one file may override
  values parsed from previous files: the last file parsed has final say. The `:overwrite?`
  option determines how the parsed values will be merged with the existing system values.

  ## Options

  - `:side_effect` an arity 1 function called after the successful parsing of each of the given files.
    The default is `&System.put_env/1`, which will have the effect of setting system environment variables based on
    the results of the file parsing.
  - `:overwrite?` boolean indicating whether or not values parsed from provided `.env` files should
    overwrite existing system environment variables. Default: `false`
  - `:parser` module that parses the given file(s). Overridable for testing.
    Default: `Dotenv.Parser`
  - `:require_files` specifies which of the given `files` (if any) *must* be present.
    When `true`, all the listed files must exist.
    When `false`, none of the listed files must exist.
    When some of the files are required and some are optional, provide a list
    specifying which files are required.
  - `:side_effect` an arity 1 function called after the successful parsing of each of the given files.
    The default is `&System.put_env/1`, which will have the effect of setting system environment variables based on
    the results of the file parsing.
  - `:vars` a map with string keys representing the starting pool of variables.
    Default: output of `System.get_env/0`.

  ## Examples

      iex> Dotenvy.source(".env")
      {:ok, %{
        "PWD" => "/users/home",
        "DATABASE_URL" => "postgres://postgres:postgres@localhost/myapp",
        # ...etc...
        }
      }

      # If you only want to return the parsed contents of the listed files
      # ignoring system environment variables altogether
      iex> Dotenvy.source(["file1", "file2"], side_effect: false, vars: %{})

  """

  @spec source(files :: binary() | [binary()], opts :: keyword()) ::
          {:ok, map()} | {:error, any()}
  def source(files, opts \\ [])

  def source(file, opts) when is_binary(file), do: source([file], opts)

  def source(files, opts) when is_list(files) do
    side_effect = Keyword.get(opts, :side_effect, &System.put_env/1)
    vars = Keyword.get(opts, :vars, System.get_env())
    overwrite? = Keyword.get(opts, :overwrite?, false)

    with {:ok, parsed_vars} <- handle_files(files, vars, opts),
         {:ok, merged_vars} <- merge_values(parsed_vars, vars, overwrite?) do
      if is_function(side_effect), do: side_effect.(merged_vars)
      {:ok, merged_vars}
    end
  end

  @doc """
  As `source/2`, but returns map on success or raises on error.
  """
  def source!(files, opts \\ [])

  def source!(file, opts) when is_binary(file), do: source!([file], opts)

  def source!(files, opts) when is_list(files) do
    case source(files, opts) do
      {:ok, vars} -> vars
      {:error, error} -> raise error
    end
  end

  defp merge_values(parsed, system_env, true) do
    {:ok, Map.merge(system_env, parsed)}
  end

  defp merge_values(parsed, system_env, false) do
    {:ok, Map.merge(parsed, system_env)}
  end

  # handles the parsing of a single file
  defp handle_files([], %{} = vars, _opts), do: {:ok, vars}

  defp handle_files([file | remaining], %{} = vars, opts) do
    parser = Keyword.get(opts, :parser, @default_parser)

    require_files = Keyword.get(opts, :require_files, false)

    with {:ok, contents} <- read_file(file, require_files),
         {:ok, new_vars} <- parser.parse(contents, vars, opts) do
      handle_files(remaining, Map.merge(vars, new_vars), opts)
    else
      :continue ->
        handle_files(remaining, vars, opts)

      {:error, error} ->
        {:error, "There was error with file #{inspect(file)}: #{inspect(error)}"}
    end
  end

  # Reads the file after checking whether or not it exists
  @spec read_file(file :: binary(), true | false | [binary()]) ::
          {:ok, binary()} | {:error, any()} | :continue
  defp read_file(file, false) do
    case File.exists?(file) do
      true -> File.read(file)
      false -> :continue
    end
  end

  defp read_file(file, true) do
    case File.exists?(file) do
      true -> File.read(file)
      false -> {:error, "file not found"}
    end
  end

  defp read_file(file, require_files) when is_list(require_files) do
    file
    |> read_file(Enum.member?(require_files, file))
  end
end
