defmodule Dotenvy.ParserTest do
  use Dotenvy.FileCase, async: true
  alias Dotenvy.Parser, as: P

  describe "parse/3 comments" do
    @tag env_file: "comments.env"
    test ":ok for comments and empty lines", %{contents: contents} do
      assert {:ok, %{}} = P.parse(contents)
    end

    @tag :skip
    # See https://docs.docker.com/compose/environment-variables/env-file/
    test "hashtags must be preceded by an empty space" do
      assert {:ok, %{"VAR" => "VAL# not a comment"}} = P.parse("VAR=VAL# not a comment")
    end
  end

  describe "parse/3 lines" do
    test ":error on improper key" do
      assert {:error, _} = P.parse("KEY_WITHOUT_VALUE\n")
    end

    test ":error on improperly closed value" do
      assert {:error, _} = P.parse("KEY=\"missing-quote")
    end

    test ":error on improper sequence before opening double-quote" do
      assert {:error, _} = P.parse("KEY=oops\"quoted\"")
    end

    test ":error on improper sequence before opening single-quote" do
      assert {:error, _} = P.parse("KEY=oops'quoted'")
    end
  end

  describe "parse/3 double-quotes" do
    @tag env_file: "double.env"
    test ":ok", %{contents: contents} do
      assert {:ok, %{"A" => "apple", "B" => " boy ", "C" => "interpolated apple"}} ==
               P.parse(contents)
    end

    test ":error on interpolating non-existing" do
      assert {:error, _} = P.parse("A=\"${B}\"", %{})
    end

    test ":error on trailing characters" do
      assert {:error, _} = P.parse("A=\"apple\" oops")
    end
  end

  describe "parse/3 multi-lines" do
    @tag env_file: "multiline.env"
    test ":ok", %{contents: contents} do
      assert {:ok,
              %{
                "MSG_A" => "\nHello from MSG_A\n",
                "MSG_B" => "Hello from MSG_B\n",
                "MSG_C" => "Hello from MSG_C\n",
                "MSG_D" => "Hello from MSG_D interpolating \"\nHello from MSG_A\n\"\n",
                "MSG_E" => "Hello from MSG_E without interpolating \"${MSG_B}\"\n",
                "MSG_F" => "\nHello from MSG_F\n",
                "MSG_G" => "\nHello from MSG_G with\nlots of text\n"
              }} ==
               P.parse(contents)
    end
  end

  describe "parse/3 escape sequences" do
    @tag env_file: "escaped.env"
    test ":ok", %{contents: contents} do
      assert {:ok, %{"A" => "\n\r\t\f\b\"\'\\\uAAAAz"}} == P.parse(contents)
    end

    test ":error for too many hex characters" do
      assert {:error, _} = P.parse("FOO=\\uZZZZoops")
    end

    test "error on invalid unicode (non base-16)" do
      assert {:error, _} = P.parse("FOO=\\uXÜ9foo")
    end

    test "error on incomplete unicode" do
      assert {:error, _} = P.parse("FOO=\\uAB")
    end
  end

  describe "parse/3 single-quotes" do
    @tag env_file: "single.env"
    test ":ok", %{contents: contents} do
      assert {:ok, %{"A" => "apple", "B" => " boy ", "C" => "non-interpolated ${A}"}} ==
               P.parse(contents)
    end
  end

  describe "parse/3 heredoc" do
    @tag env_file: "heredoc.env"
    test ":ok", %{contents: contents} do
      assert {
               :ok,
               %{
                 "A" => "apple\n",
                 "B" => "No substitution ${A}\n",
                 "C" => "Substitution apple\n\n"
               }
             } == P.parse(contents)
    end

    @tag env_file: "heredoc-bad-open.env"
    test ":error on trailing non-whitespace following opening", %{contents: contents} do
      assert {:error, _} = P.parse(contents)
    end

    @tag env_file: "heredoc-bad-open2.env"
    test ":error when opening is preceded by non-whitespace (single-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag env_file: "heredoc-bad-open3.env"
    test ":error when opening is preceded by non-whitespace (double-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag env_file: "heredoc-bad-open4.env"
    test ":error when opening is followed by non-whitespace (double-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag env_file: "heredoc-bad-close.env"
    test ":error on trailing non-whitespace (single-quote)", %{contents: contents} do
      assert {:error, _} = P.parse(contents)
    end

    @tag env_file: "heredoc-bad-close2.env"
    test ":error on trailing non-whitespace (double-quote)", %{contents: contents} do
      assert {:error, _} = P.parse(contents)
    end
  end

  describe "parse/3 interpolation" do
    test ":error when interpolated variable lacks closing brace" do
      assert {:error, _} = P.parse("A=${B", %{})
    end
  end

  describe "parse/3 unquoted" do
    @tag env_file: "unquoted.env"
    test ":ok", %{contents: contents} do
      assert {:ok,
              %{
                "A" => "one-word",
                "B" => "trim me",
                "C" => "with spaces",
                "D" => "interpolated vars one-word"
              }} == P.parse(contents)
    end

    test ":error on interpolating non-existing var" do
      assert {:error, _} = P.parse("A=${B}", %{})
    end
  end

  describe "parse/3 variable names" do
    @tag env_file: "varnames.env"
    test ":ok", %{contents: contents} do
      assert {:ok, _} = P.parse(contents)
    end

    test ":error when there is no value" do
      assert {:error, _} = P.parse("NO_VALUE")
    end

    test ":error when variable begins with number" do
      assert {:error, _} = P.parse("2bad=nope")
    end

    test ":error when variable contains spaces" do
      assert {:error, _} = P.parse("NOT GOOD=")
    end

    test ":error when variable contains unicode" do
      assert {:error, _} = P.parse("SÜPER=")
    end

    test ":error when variable contains hyphen" do
      assert {:error, _} = P.parse("NOT-ALLOWED=")
    end
  end

  describe "parse/3 shell commands" do
    test ":ok" do
      assert {:ok, %{"FOO" => "this-is-a-test"}} = P.parse("FOO=$(echo this-is-a-test)")
    end

    test "commands not executed in single-quoted lines" do
      assert {:ok, %{"FOO" => "$(echo this-is-a-test)"}} =
               P.parse("FOO='$(echo this-is-a-test)'")
    end

    test ":error on empty command" do
      assert {:error, _} = P.parse("FOO=$()")
    end

    test ":sys_cmd_fn" do
      assert {:ok, %{"FOO" => "echo this-is-a-test"}} =
               P.parse("FOO=$(echo this-is-a-test)", %{},
                 sys_cmd_fn: fn cmd, args, _opts -> {"#{cmd} #{Enum.join(args)}", 0} end
               )
    end
  end
end
