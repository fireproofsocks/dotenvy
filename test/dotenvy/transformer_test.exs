defmodule Dotenvy.TransformerTest do
  use ExUnit.Case
  alias Dotenvy.Transformer, as: T

  describe "to!/2 :atom" do
    test "conversion" do
      assert :debug = T.to!("debug", :atom)
    end

    test "conversion strips leading colon" do
      assert :debug = T.to!(":debug", :atom)
    end
  end

  describe "to!/2 :atom?" do
    test "nil conversion", do: assert(nil == T.to!("", :atom?))
    test "conversion", do: assert(:dev == T.to!("dev", :atom?))
  end

  describe "to!/2 :atom!" do
    test "nil raise" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :atom!)
      end
    end

    test "conversion", do: assert(:dev == T.to!("dev", :atom!))
  end

  describe "to!/2 :boolean" do
    test "empty string false" do
      assert false == T.to!("", :boolean)
    end

    test "zero to false" do
      assert false == T.to!("0", :boolean)
    end

    test "false to false" do
      assert false == T.to!("false", :boolean)
    end

    test "false to false case insensitive" do
      assert false == T.to!("FALSE", :boolean)
    end

    test "other to true" do
      assert true == T.to!("anything", :boolean)
    end
  end

  describe "to!/2 :boolean?" do
    test "empty string null" do
      assert nil == T.to!("", :boolean?)
    end

    test "false to false" do
      assert false == T.to!("false", :boolean?)
    end
  end

  describe "to!/2 :boolean!" do
    test "empty string raises" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :boolean!)
      end
    end

    test "false to false" do
      assert false == T.to!("false", :boolean!)
    end
  end

  describe "to!/2 :charlist" do
    test "convert" do
      assert ~c"foo" == T.to!("foo", :charlist)
    end

    test "empty to empty" do
      assert ~c"" == T.to!("", :charlist)
    end
  end

  describe "to!/2 :charlist?" do
    test "empty string to nil" do
      assert nil == T.to!("", :charlist?)
    end

    test "convert" do
      assert ~c"foo" == T.to!("foo", :charlist?)
    end
  end

  describe "to!/2 :charlist!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :charlist!)
      end
    end

    test "convert" do
      assert ~c"foo" == T.to!("foo", :charlist!)
    end
  end

  describe "to!/2 :existing_atom" do
    test "convert" do
      assert :dev == T.to!("dev", :existing_atom)
    end

    test "raise when value is not existing atom" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("this-is-not-existing", :existing_atom)
      end
    end
  end

  describe "to!/2 :existing_atom?" do
    test "empty string to nil" do
      assert nil == T.to!("", :existing_atom?)
    end

    test "convert" do
      assert :dev == T.to!("dev", :existing_atom?)
    end
  end

  describe "to!/2 :existing_atom!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :existing_atom!)
      end
    end

    test "convert" do
      assert :dev == T.to!("dev", :existing_atom!)
    end
  end

  describe "to!/2 :float" do
    test "convert" do
      assert 12.3 = T.to!("12.3", :float)
    end

    test "empty string to zero" do
      assert 0.0 === T.to!("", :float)
    end

    test "raises on unparsable" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("Abc", :float)
      end
    end
  end

  describe "to!/2 :float?" do
    test "empty string to nil" do
      assert nil == T.to!("", :float?)
    end

    test "convert" do
      assert 12.3 == T.to!("12.3", :float?)
    end
  end

  describe "to!/2 :float!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :float!)
      end
    end

    test "convert" do
      assert 12.3 == T.to!("12.3", :float!)
    end
  end

  describe "to!/2 :integer" do
    test "empty string to 0" do
      assert 0 = T.to!("", :integer)
    end

    test "positive" do
      assert 123 = T.to!("123", :integer)
    end

    test "negative" do
      assert -123 = T.to!("-123", :integer)
    end

    test "raises on unparsable" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("Abc", :integer)
      end
    end
  end

  describe "to!/2 :integer?" do
    test "empty string to nil" do
      assert nil == T.to!("", :integer?)
    end

    test "conversion" do
      assert 12 == T.to!("12", :integer?)
    end
  end

  describe "to!/2 :integer!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :integer!)
      end
    end

    test "convert" do
      assert 12 == T.to!("12", :integer!)
    end
  end

  describe "to!/2 :ip?" do
    test "converts IPv4" do
      assert {127, 0, 0, 1} === T.to!("127.0.0.1", :ip?)
    end

    test "converts IPv6" do
      assert {8193, 3512, 0, 0, 0, 0, 0, 1} === T.to!("2001:db8::1", :ip?)
    end

    test "empty string to nil" do
      assert nil == T.to!("", :ip?)
    end

    test "raises on unparsable" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("nonsense", :ip?)
      end
    end
  end

  describe "to!/2 :ip!" do
    test "converts IPv4" do
      assert {127, 0, 0, 1} === T.to!("127.0.0.1", :ip!)
    end

    test "converts IPv6" do
      assert {8193, 3512, 0, 0, 0, 0, 0, 1} === T.to!("2001:db8::1", :ip!)
    end

    test "empty string raises" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :ip!)
      end
    end

    test "rejects abbreviated IPv4 forms" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("127.1", :ip!)
      end
    end
  end

  describe "to!/2 :ipv4?" do
    test "convert" do
      assert {127, 0, 0, 1} === T.to!("127.0.0.1", :ipv4?)
    end

    test "empty string to nil" do
      assert nil == T.to!("", :ipv4?)
    end

    test "rejects IPv6" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("2001:db8::1", :ipv4?)
      end
    end
  end

  describe "to!/2 :ipv4!" do
    test "convert" do
      assert {0, 0, 0, 0} === T.to!("0.0.0.0", :ipv4!)
    end

    test "empty string raises" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :ipv4!)
      end
    end

    test "rejects abbreviated forms" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("127.1", :ipv4!)
      end

      assert_raise Dotenvy.Error, fn ->
        T.to!("0x7f.1", :ipv4!)
      end
    end
  end

  describe "to!/2 :ipv6?" do
    test "convert" do
      assert {8193, 3512, 0, 0, 0, 0, 0, 1} === T.to!("2001:db8::1", :ipv6?)
    end

    test "long and short forms agree" do
      assert T.to!("2001:0db8:0000:0000:0000:0000:0000:0001", :ipv6?) ===
               T.to!("2001:db8::1", :ipv6?)
    end

    test "empty string to nil" do
      assert nil == T.to!("", :ipv6?)
    end

    test "rejects IPv4" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("127.0.0.1", :ipv6?)
      end
    end
  end

  describe "to!/2 :ipv6!" do
    test "convert" do
      assert {0, 0, 0, 0, 0, 0, 0, 1} === T.to!("::1", :ipv6!)
    end

    test "empty string raises" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :ipv6!)
      end
    end
  end

  describe "to!/2 :module" do
    test "conversion" do
      assert Dotenvy.TransformerTest == T.to!("Dotenvy.TransformerTest", :module)
    end

    test "empty string" do
      assert :"Elixir." == T.to!("", :module)
    end
  end

  describe "to!/2 :module?" do
    test "empty string to nil" do
      assert nil == T.to!("", :module?)
    end

    test "convert" do
      assert Dotenvy.TransformerTest == T.to!("Dotenvy.TransformerTest", :module?)
    end
  end

  describe "to!/2 :module!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :module!)
      end
    end

    test "convert" do
      assert Dotenvy.TransformerTest == T.to!("Dotenvy.TransformerTest", :module!)
    end
  end

  describe "to!/2 :string" do
    test "convert (i.e. no conversion)" do
      assert "foo" == T.to!("foo", :string)
    end
  end

  describe "to!/2 :string?" do
    test "empty string to nil" do
      assert nil == T.to!("", :string?)
    end

    test "convert" do
      assert "foo" == T.to!("foo", :string?)
    end
  end

  describe "to!/2 :string!" do
    test "raise on empty string" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("", :string!)
      end
    end

    test "convert" do
      assert "foo" == T.to!("foo", :string!)
    end
  end

  describe "to!/2 custom callback function" do
    test "do custom modification" do
      assert "foobar" == T.to!("foo", fn val -> "#{val}bar" end)
    end
  end

  describe "to!/2 IP types have no suffix-less variant" do
    test "bare types are unknown" do
      for type <- [:ip, :ipv4, :ipv6] do
        assert_raise Dotenvy.Error, fn ->
          T.to!("127.0.0.1", type)
        end
      end
    end
  end

  describe "to!/2 errors" do
    test "unsupported type" do
      assert_raise Dotenvy.Error, fn ->
        T.to!("ff", :not_supported)
      end
    end

    test "unsupported input" do
      assert_raise Dotenvy.Error, fn ->
        T.to!(false, :string)
      end
    end
  end
end
