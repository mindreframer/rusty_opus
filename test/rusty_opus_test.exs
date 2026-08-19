defmodule RustyOpusTest do
  use ExUnit.Case, async: true

  doctest RustyOpus

  test "the native boundary is live and reports a version" do
    assert {:ok, version} = RustyOpus.native_smoke()
    assert version == "0.3.2"
  end

  test "a deterministic native error translates without crashing" do
    assert {:error, %RustyOpus.Error{reason: :native, message: "deterministic native error"}} =
             RustyOpus.translated_error()
  end

  test "a native panic is contained at the NIF boundary" do
    assert {:error, :contained_panic} = RustyOpus.contained_panic()
  end

  test "the runtime survives after a contained panic" do
    assert {:error, :contained_panic} = RustyOpus.contained_panic()
    assert {:ok, _} = RustyOpus.native_smoke()
  end

  test "a disposable child BEAM runs (boundary proof)" do
    assert {:ok, out} = RustyOpus.TestHelpers.ChildBEAM.smoke()
    assert out =~ "child-ok"
  end
end
