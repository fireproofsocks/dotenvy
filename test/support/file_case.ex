defmodule Dotenvy.FileCase do
  @moduledoc """
  Supports tests that need to load files from inside `test/support/files/`.
  To use this in a test, `use` this module and annotate your test functions
  with `@tag env_file: "rel/path/to/file"`, and receive the `contents` key from the
  context argument, e.g.

      defmodule ExampleTest do
        use Dotenvy.FileCase

        @tag env_file: "a.env"
        test "something", %{contents: contents} do
          # assertions here
        end
      end

  The `@file` tag might make more sense, but that is a reserved tag within tests.
  """

  use ExUnit.CaseTemplate

  # Setup a pipeline for the context metadata
  setup [:append_file_contents]

  defp append_file_contents(%{env_file: filename}) when is_binary(filename) do
    %{contents: get_file_contents(filename)}
  end

  defp append_file_contents(context), do: context

  @doc """
  Loads up a supporting file from the relative path inside `test/support/files/`
  """
  def get_file_contents(filename) do
    "test/support/files/#{filename}"
    |> File.read!()
  end
end
