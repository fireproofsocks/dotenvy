defmodule Dotenvy.ParserTest do
  use Dotenvy.FileCase, async: true
  alias Dotenvy.Parser, as: P

  describe "parse/3 comments" do
    @tag contents: "comments.env"
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
    @tag contents: "double.env"
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

  describe "parse/3 escape sequences" do
    @tag contents: "escaped.env"
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
    @tag contents: "single.env"
    test ":ok", %{contents: contents} do
      assert {:ok, %{"A" => "apple", "B" => " boy ", "C" => "non-interpolated ${A}"}} ==
               P.parse(contents)
    end
  end

  describe "parse/3 heredoc" do
    @tag contents: "heredoc.env"
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

    @tag contents: "heredoc-bad-open.env"
    test ":error on trailing non-whitespace following opening", %{contents: contents} do
      assert {:error, _} = P.parse(contents)
    end

    @tag contents: "heredoc-bad-open2.env"
    test ":error when opening is preceded by non-whitespace (single-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag contents: "heredoc-bad-open3.env"
    test ":error when opening is preceded by non-whitespace (double-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag contents: "heredoc-bad-open4.env"
    test ":error when opening is followed by non-whitespace (double-quotes)", %{
      contents: contents
    } do
      assert {:error, _} = P.parse(contents)
    end

    @tag contents: "heredoc-bad-close.env"
    test ":error on trailing non-whitespace (single-quote)", %{contents: contents} do
      assert {:error, _} = P.parse(contents)
    end

    @tag contents: "heredoc-bad-close2.env"
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
    @tag contents: "unquoted.env"
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
    @tag contents: "varnames.env"
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
end
