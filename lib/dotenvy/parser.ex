defmodule Dotenvy.Parser do
  @moduledoc """
  This module handles the parsing of the contents of `.env` files into maps with
  string keys. See [Dotenv File Format](docs/dotenv-file-format.md) for details
  on the supported file format.

  This implementation uses parsing over regular expressions for most of its work.
  """
  @behaviour Dotenvy

  # Formalizes parser opts
  defmodule Opts do
    @moduledoc false
    defstruct interpolate?: true,
              stop_on: nil,
              key: nil
  end

  @doc """
  Parse the given `contents`, substituting and merging with the given `vars`.
  """
  # The parsing bounces between seeking keys and seeking values.
  @impl true
  def parse(contents, vars \\ %{}, _opts \\ []) when is_binary(contents) do
    find_key(contents, "", vars)
  end

  # EOF. Done!
  defp find_key("", acc, vars) do
    case String.trim(acc) do
      "" -> {:ok, vars}
      _ -> {:error, "Invalid syntax: variable missing value"}
    end
  end

  defp find_key(<<?#, tail::binary>>, _acc, vars) do
    tail
    |> fast_forward_to_line_end()
    |> find_key("", vars)
  end

  # When we hit the equals sign, we look at what we have accumulated
  # to see if it is a valid variable name (i.e. a key).
  defp find_key(<<?=, tail::binary>>, acc, vars) do
    key =
      acc
      |> String.trim_leading("export ")
      |> String.trim()

    case Regex.match?(~r/(^[a-zA-Z_]+[a-zA-Z0-9_]*$)/, key) do
      true ->
        find_value(tail, "", vars, %Opts{key: key, stop_on: nil})

      _ ->
        {:error, "Invalid variable name syntax: #{inspect(acc)}"}
    end
  end

  defp find_key(<<?\n, tail::binary>>, acc, vars) do
    case String.trim(acc) do
      "" -> find_key(tail, "", vars)
      _ -> {:error, "Invalid syntax for line. No equals sign for key: #{inspect(acc)}"}
    end
  end

  # Shift the char onto the accumulator and keep looking...
  defp find_key(<<char::utf8, tail::binary>>, acc, vars) do
    find_key(tail, acc <> <<char>>, vars)
  end

  #######################################
  # Find the value for the given key
  # STRAVO : STRing, Accumulator, Vars, Opts
  #######################################
  # is the rest of the line free from debris?
  defp find_value(
         <<?', ?', ?', tail::binary>>,
         acc,
         %{} = vars,
         %Opts{key: key, stop_on: nil}
       ) do
    case String.trim(acc) do
      "" ->
        {tail, acc} = accumulate_rest_of_line(tail, "")

        case String.trim(acc) do
          "" ->
            find_value(tail, "", vars, %Opts{
              key: key,
              interpolate?: false,
              stop_on: <<?', ?', ?'>>
            })

          _ ->
            {:error,
             "Key: #{key}: heredoc allows only zero or more whitespace characters followed by a new line after '''"}
        end

      _ ->
        {:error, "Key: #{key}: Improper syntax before opening heredoc: #{inspect(acc)}"}
    end
  end

  defp find_value(
         <<?", ?", ?", tail::binary>>,
         acc,
         %{} = vars,
         %Opts{key: key, stop_on: nil}
       ) do
    case String.trim(acc) do
      "" ->
        {tail, acc} = accumulate_rest_of_line(tail, "")

        case String.trim(acc) do
          "" ->
            find_value(tail, "", vars, %Opts{
              key: key,
              interpolate?: true,
              stop_on: <<?", ?", ?">>
            })

          _ ->
            {:error,
             "Key: #{key}: heredoc allows only zero or more whitespace characters followed by a new line after \"\"\""}
        end

      _ ->
        {:error, "Key: #{key}: Improper syntax before opening heredoc: #{inspect(acc)}"}
    end
  end

  defp find_value(
         <<h::binary-size(3), tail::binary>>,
         acc,
         vars,
         %Opts{key: key, stop_on: stop}
       )
       when h == stop and stop != nil do
    {tail, rest_of_line} = accumulate_rest_of_line(tail, "")

    case String.trim(rest_of_line) do
      "" -> find_key(tail, "", Map.put(vars, key, acc))
      _ -> {:error, "Invalid syntax following #{inspect(stop)}: #{inspect(rest_of_line)}"}
    end
  end

  defp find_value(
         <<?", tail::binary>>,
         acc,
         vars,
         %Opts{key: key, stop_on: nil}
       ) do
    case String.trim(acc) do
      "" ->
        find_value(tail, "", vars, %Opts{key: key, interpolate?: true, stop_on: <<?">>})

      _ ->
        {:error, "Improper syntax before opening quote: #{inspect(acc)}"}
    end
  end

  defp find_value(
         <<?', tail::binary>>,
         acc,
         vars,
         %Opts{key: key, stop_on: nil}
       ) do
    case String.trim(acc) do
      "" ->
        find_value(tail, "", vars, %Opts{key: key, interpolate?: false, stop_on: <<?'>>})

      _ ->
        {:error, "Improper syntax before opening quote: #{inspect(acc)}"}
    end
  end

  # Comment - ignore the rest of the line
  defp find_value(<<?#, tail::binary>>, acc, vars, %Opts{key: key, stop_on: nil} = _opts) do
    tail
    |> fast_forward_to_line_end()
    |> find_key("", Map.put(vars, key, String.trim(acc)))
  end

  # End of un-quoted line, EOF
  defp find_value("", acc, vars, %Opts{key: key, stop_on: nil} = _opts)
       when key != nil do
    {:ok, Map.put(vars, key, String.trim(acc))}
  end

  # End of un-quoted line
  defp find_value(
         <<?\n, tail::binary>>,
         acc,
         vars,
         %Opts{key: key, stop_on: nil} = _opts
       )
       when key != nil do
    find_key(tail, "", Map.put(vars, key, String.trim(acc)))
  end

  # Variable interpolation
  defp find_value(<<?$, ?{, tail::binary>>, acc, vars, %Opts{interpolate?: true} = opts) do
    case acc_varname(tail, "", <<?}>>) do
      {:ok, acc_varname, tail} ->
        varname = String.trim(acc_varname)

        case Map.fetch(vars, varname) do
          :error -> {:error, "Could not interpolate variable ${#{varname}}: variable undefined."}
          {:ok, val} -> find_value(tail, acc <> val, vars, opts)
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp find_value(
         <<h::binary-size(1), tail::binary>>,
         acc,
         vars,
         %Opts{key: key, stop_on: stop}
       )
       when h == stop and stop != nil do
    {tail, rest_of_line} = accumulate_rest_of_line(tail, "")

    case String.trim(rest_of_line) do
      "" ->
        find_key(tail, "", Map.put(vars, key, acc))

      _ ->
        {:error,
         "Invalid syntax for key #{key} following #{inspect(stop)}: #{inspect(rest_of_line)}"}
    end
  end

  # Escape sequences
  defp find_value(
         <<?\\, char::utf8, tail::binary>>,
         acc,
         vars,
         %Opts{interpolate?: true} = opts
       ) do
    case char do
      ?n -> find_value(tail, acc <> "\n", vars, opts)
      ?r -> find_value(tail, acc <> "\r", vars, opts)
      ?t -> find_value(tail, acc <> "\t", vars, opts)
      ?f -> find_value(tail, acc <> "\f", vars, opts)
      ?b -> find_value(tail, acc <> "\b", vars, opts)
      ?" -> find_value(tail, acc <> "\"", vars, opts)
      ?' -> find_value(tail, acc <> "\'", vars, opts)
      ?\\ -> find_value(tail, acc <> "\\", vars, opts)
      ?u -> do_unicode(tail, acc, vars, opts)
      # for any other character, we just drop the backslash
      _ -> find_value(tail, acc <> <<char::utf8>>, vars, opts)
    end
  end

  defp find_value("", _acc, _vars, %Opts{key: key, stop_on: stop} = _opts)
       when key != nil and stop != nil do
    {:error,
     "Could not parse value for #{inspect(key)}. Stop sequence not found: #{inspect(stop)}"}
  end

  defp find_value(<<char::utf8, tail::binary>>, acc, vars, opts) do
    find_value(tail, acc <> <<char>>, vars, opts)
  end

  # More limited helper function... for getting varnames? and?
  defp acc_varname(<<h::binary-size(1), tail::binary>>, acc, stop) when h == stop do
    {:ok, acc, tail}
  end

  defp acc_varname(<<char::utf8, tail::binary>>, acc, stop) do
    acc_varname(tail, acc <> <<char>>, stop)
  end

  defp acc_varname("", _acc, stop) do
    {:error, "Stop sequence not found: #{inspect(stop)}"}
  end

  @spec accumulate_rest_of_line(tail :: binary(), acc :: binary()) :: {binary(), binary()}
  defp accumulate_rest_of_line("", acc), do: {"", acc}
  defp accumulate_rest_of_line(<<?\n, tail::binary>>, acc), do: {tail, acc}

  defp accumulate_rest_of_line(<<?#, tail::binary>>, acc) do
    {fast_forward_to_line_end(tail), acc}
  end

  defp accumulate_rest_of_line(<<char::utf8, tail::binary>>, acc) do
    accumulate_rest_of_line(tail, acc <> <<char>>)
  end

  defp do_unicode(<<hex_chars::binary-size(4), tail::binary>>, acc, vars, %Opts{key: key} = opts) do
    case Integer.parse(hex_chars, 16) do
      {as_integer, ""} -> find_value(tail, acc <> <<as_integer::utf8>>, vars, opts)
      _ -> {:error, "Invalid unicode format for key #{key}: \\u#{hex_chars}"}
    end
  end

  defp do_unicode(_, _, _, %Opts{key: key}) do
    {:error, "Invalid unicode format for key #{key}: incomplete"}
  end

  # Moves the cursor up to the next line, e.g. after a `#`
  # EOF
  defp fast_forward_to_line_end(""), do: ""

  defp fast_forward_to_line_end(<<?\n, tail::binary>>), do: tail

  defp fast_forward_to_line_end(<<_::binary-size(1), tail::binary>>) do
    fast_forward_to_line_end(tail)
  end
end
