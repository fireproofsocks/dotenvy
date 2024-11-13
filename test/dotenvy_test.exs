defmodule DotenvyTest do
  use ExUnit.Case, async: true

  import Dotenvy
  import Mox

  setup :verify_on_exit!

  describe "env!/3" do
    test "returns default when variable not set" do
      assert "some-default" = env!("DOES_NOT_EXIST", :string, "some-default")
    end

    test "returns value when env set and sourced", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")

      assert_raise RuntimeError, fn ->
        env!("TEST_VALUE", :string)
      end

      source([System.get_env()])
      assert "#{test}" == env!("TEST_VALUE", :string, nil)
    end

    test "built-in conversion errors convert to RuntimeError", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise RuntimeError, fn ->
        env!("TEST_VALUE", :integer, 123)
      end
    end

    test "raising Dotenvy.Error with custom message converts to RuntimeError", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise RuntimeError, ~r/Custom error/, fn ->
        env!(
          "TEST_VALUE",
          fn _ ->
            raise Dotenvy.Error, message: "Custom error"
          end,
          "default"
        )
      end
    end

    test "raising other error types passes thru", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise FunctionClauseError, fn ->
        env!("TEST_VALUE", fn _ -> Keyword.get(%{}, :foo) end, "default")
      end
    end
  end

  describe "env!/2" do
    test "default type is string", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])
      assert "#{test}" == env!("TEST_VALUE")
    end

    test "raises when variable not set" do
      assert_raise RuntimeError, fn ->
        env!("DOES_NOT_EXIST", :string!)
      end
    end

    test "built-in conversion errors convert to RuntimeError", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise RuntimeError, fn ->
        env!("TEST_VALUE", :integer)
      end
    end

    test "raising Dotenvy.Error with custom message converts to RuntimeError", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise RuntimeError, ~r/Custom error/, fn ->
        env!("TEST_VALUE", fn _ ->
          raise Dotenvy.Error, message: "Custom error"
        end)
      end
    end

    test "raising other error types passes thru", %{test: test} do
      System.put_env("TEST_VALUE", "#{test}")
      source([System.get_env()])

      assert_raise FunctionClauseError, fn ->
        env!("TEST_VALUE", fn _ -> Keyword.get(%{}, :foo) end)
      end
    end
  end

  describe "source/2" do
    test ":ok when no files parsed" do
      assert {:ok, %{}} == source("does_not_exist")
    end

    test "merges maps" do
      assert {:ok, %{"A" => "2", "B" => "3"}} ==
               source([%{"A" => "1"}, %{"A" => "2", "B" => "3"}])
    end

    test "last file overwrites previous values" do
      assert {:ok, %{"A" => "alpha", "B" => "ball"}} =
               source(["test/support/files/a.env", "test/support/files/b.env"], vars: %{})
    end

    test "system env vars not set when listed in sourced file" do
      assert {:ok, _} = source(["test/support/files/a.env"])
      assert :error == System.fetch_env("B")
    end

    test "source variables available to env!/2", %{test: test} do
      {:ok, _} = source([%{"#{test}" => "#{test}"}])
      assert "#{test}" == env!("#{test}")
    end

    test "enforces list of :require_files" do
      assert {:ok, _} =
               source(["test/support/files/a.env", "test/support/files/b.env"],
                 require_files: ["test/support/files/a.env", "test/support/files/b.env"]
               )
    end

    test "error when :require_files references files not in input" do
      assert {:error, _} =
               source(["test/support/files/a.env", "test/support/files/b.env"],
                 require_files: ["test/support/files/c.env"]
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
      assert ^vars = source!([%{"foo" => "bar"}, "does_not_exist"], side_effect: false)
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
