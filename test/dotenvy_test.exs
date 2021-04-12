defmodule DotenvyTest do
  use ExUnit.Case, async: false

  import Dotenvy
  import Mox

  setup :verify_on_exit!

  describe "env/3" do
    test "returns default when variable not set" do
      assert "some-default" = env("DOES_NOT_EXIST", :string, "some-default")
    end

    test "returns value when env set", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      assert "#{test}" == env("TEST_VALUE", :string, nil)
    end
  end

  describe "env!/2" do
    test "raises when variable not set" do
      assert_raise ArgumentError, fn ->
        env!("DOES_NOT_EXIST", :string!)
      end
    end
  end

  describe "source/2" do
    test ":ok when no files parsed" do
      assert {:ok, _} = source("does_not_exist")
    end

    test "last file overwrites previous values" do
      assert {:ok, %{"A" => "alpha", "B" => "ball"}} =
               source(["test/support/files/a.env", "test/support/files/b.env"])
    end

    test "sets system env vars" do
      assert {:ok, _} = source(["test/support/files/a.env"])
      assert "ball" == System.get_env("B")
    end

    test "enforces list of :require_files" do
      assert {:ok, _} =
               source(["test/support/files/a.env", "test/support/files/b.env"],
                 require_files: ["test/support/files/a.env", "test/support/files/b.env"]
               )
    end

    test "calls side_effect function" do
      pid = self()

      source(["test/support/files/a.env", "test/support/files/b.env"],
        side_effect: fn _ -> send(pid, :side_effect) end
      )

      assert_receive :side_effect
    end
  end

  describe "source!/2" do
    test "ok with default options" do
      assert %{} = source!("does_not_exist")
    end

    test "ok" do
      vars = %{"foo" => "bar"}
      assert ^vars = source!("does_not_exist", vars: vars, side_effect: false)
    end

    test "raises on missing file when file is required" do
      assert_raise RuntimeError, fn ->
        source!("does_not_exist", require_files: true)
      end
    end

    test "raises on parser error" do
      parser =
        ParserMock
        |> expect(:parse, fn _, _, _ -> {:error, "Problem"} end)

      assert_raise RuntimeError, fn ->
        source!("test/support/files/a.env", parser: parser)
      end
    end
  end
end
