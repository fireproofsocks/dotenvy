defmodule Dotenvy do
  @moduledoc """
  `Dotenvy` is an Elixir port of the original [dotenv](https://github.com/bkeepers/dotenv) Ruby gem.

  It is designed to help applications follow the principles of
  the [12-factor app](https://12factor.net/) and its recommendation to store
  configuration in the environment.

  Unlike other configuration helpers, `Dotenvy` enforces no convention for the naming
  of your files: `.env` is a common choice, you may name your configuration files whatever
  you wish.

  See the [strategies](docs/strategies.md) for examples of various use cases.
  """

  import Dotenvy.Transformer

  alias Dotenvy.Transformer.Error

  require Logger

  @default_parser Dotenvy.Parser

  @doc """
  A parser implementation should receive the `contents` read from a file,
  a map of `vars` (with string keys, as would come from `System.get_env/0`),
  and a keyword list of `opts`.

  This callback is provided to help facilitate testing. See `Dotenvy.Parser`
  for the default implementation.
  """
  @callback parse(contents :: binary(), vars :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Reads a sourced variable and converts its output or returns a default value.
  Use of `env!/2` is usually recommended over `env!/3` because it creates a stronger contract with
  the environment (i.e. your app literally will not start if required env variables are missing)
  but there are times where supplying default values is desirable, and the `env!/3` function is
  appropriate for those situations.

  If the given `variable` is *set*, its value is converted to
  the given `type`. The provided `default` value is _only_ used when the
  variable is _not_ set; **the `default` value is returned as-is, without conversion**.
  This allows greater control of the output.

  Although this relies on `Application.fetch_env/1`, it may still raise an error
  if an unsupported `type` is provided or if non-empty values are required because
  the conversion is delegated to `Dotenvy.Transformer.to!/2` -- see its documentation
  for a list of supported types.

  This function does *not* read from `System` directly: it reads values that have been
  sourced by the `source/2` or `source!/2` functions.

  ## Examples

      iex> env!("PORT", :integer, 5432)
      5433
      iex> env!("NOT_SET", :boolean, %{not: "converted"})
      %{not: "converted"}
      iex> System.put_env("HOST", "")
      iex> source([".env", ...])
      iex> env!("HOST", :string!, "localhost")
      ** (RuntimeError) Error converting HOST to string!: non-empty value required
  """
  @doc since: "0.3.0"
  @spec env!(variable :: binary(), type :: atom(), default :: any()) :: any() | no_return()
  def env!(variable, type, default) do
    case fetch_var(variable) do
      :error -> default
      {:ok, value} -> to!(value, type)
    end
  rescue
    error in Error ->
      reraise "Error converting #{variable} to #{type}: #{error.message}", __STACKTRACE__
  end

  @deprecated "Use `Dotenvy.env!/3` instead"
  @spec env(variable :: binary(), type :: atom(), default :: any()) :: any() | no_return()
  def env(variable, type \\ :string, default \\ nil)

  def env(variable, type, default), do: env!(variable, type, default)

  @doc """
  Reads the given sourced `variable` and converts its value to the given `type`.
  This function does not read directly from `System`; values must first be sourced via
  `source/2` or `source!/2`.

  Internally, this behaves like `System.fetch_env!/1`: it will raise if a variable is
  not set or if empty values are encounted when non-empty values are required.

  Type conversion is delegated to `Dotenvy.Transformer.to!/2` -- see its documentation
  for a list of supported types.

  ## Examples

      iex> env!("PORT", :integer)
      5432
      iex> env!("ENABLED", :boolean)
      true
  """
  @spec env!(variable :: binary(), type :: atom()) :: any() | no_return()
  def env!(variable, type \\ :string)

  def env!(variable, type) do
    case fetch_var(variable) do
      :error -> raise "Application environment variable #{variable} not set"
      {:ok, value} -> to!(value, type)
    end
  rescue
    error in Error ->
      reraise "Error converting variable #{variable} to #{type}: #{error.message}", __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  @doc """
  Like Bash's `source` command, this loads the given file(s) and stores the values via
  a side effect function (which relies on `Application.put_env/4`).

  Files are processed in the order they are given. Values parsed from one file may override
  values parsed from previous files: the last file parsed has final say. The `:overwrite?`
  option determines how the parsed values will be merged with the existing system values.

  ## Options

  - `:overwrite?` boolean indicating whether or not values parsed from provided `.env` files should
    overwrite existing system environment variables. It is recommended to keep this `false`:
    setting it to `true` would prevent you from setting variables on the command line, e.g.
    `LOG_LEVEL=debug iex -S mix` Default: `false`

  - `:parser` module that implements `c:Dotenvy.parse/3` callback. Default: `Dotenvy.Parser`

  - `:require_files` specifies which of the given `files` (if any) *must* be present.
    When `true`, all the listed files must exist.
    When `false`, none of the listed files must exist.
    When some of the files are required and some are optional, provide a list
    specifying which files are required. If a file listed here is not included
    in the function's `files` argument, it is ignored. Default: `false`

  - `:side_effect` an arity 1 function called after the successful parsing of each of the given files.
    The default is an internal function that stores the values inside the application process dictionary.

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
      # ignoring side-effects altogether
      iex> Dotenvy.source(["file1", "file2"], side_effect: false, vars: %{})

  """
  @spec source(files :: binary() | [binary()], opts :: keyword()) ::
          {:ok, %{optional(String.t()) => String.t()}} | {:error, any()}
  def source(files, opts \\ [])

  def source(file, opts) when is_binary(file), do: source([file], opts)

  def source(files, opts) when is_list(files) do
    side_effect = Keyword.get(opts, :side_effect, &put_all_vars/1)

    vars = Keyword.get(opts, :vars, System.get_env())
    overwrite? = Keyword.get(opts, :overwrite?, false)
    require_files = Keyword.get(opts, :require_files, false)

    with :ok <- verify_files(files, require_files),
         {:ok, parsed_vars} <- handle_files(files, vars, opts),
         {:ok, merged_vars} <- merge_values(parsed_vars, vars, overwrite?) do
      if is_function(side_effect), do: side_effect.(merged_vars)
      {:ok, merged_vars}
    end
  end

  @doc """
  As `source/2`, but returns map on success or raises on error.
  """
  @spec source!(files :: binary() | [binary()], opts :: keyword()) ::
          %{optional(String.t()) => String.t()} | no_return()
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

  defp fetch_var(variable) do
    :dotenvy
    |> Application.get_env(:vars, %{})
    |> Map.fetch(variable)
  end

  defp put_all_vars(vars) do
    Application.put_env(:dotenvy, :vars, vars)
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

  @spec verify_files(list(), list() | boolean()) :: :ok | {:error, any()}
  defp verify_files(_, true), do: :ok
  defp verify_files(_, false), do: :ok

  defp verify_files(input, require_files) do
    input_set = MapSet.new(input)
    required_set = MapSet.new(require_files)

    case MapSet.equal?(required_set, input_set) || MapSet.subset?(required_set, input_set) do
      true -> :ok
      false -> {:error, ":require_files includes"}
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
