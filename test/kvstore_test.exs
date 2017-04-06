defmodule KVTest do
  use ExUnit.Case
  use Plug.Test
  require KVStore.Storage

  @opts KVStore.Router.init([])

  setup do
    KVStore.Storage.clear()
    {:ok, %{}}
  end

  test "create" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
  end

  test "create_ttl" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 500) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    :timer.sleep(600)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "update" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.update(:a, :b, 0) == :does_not_exist)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "update_ttl" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.update(:a, :b, 500) == :does_not_exist)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "delete" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.delete(:a) == :does_not_exist)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "dual_create" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    assert(KVStore.Storage.create(:a, :c, 0) == :already_exist)
    assert(KVStore.Storage.read(:a) == {:value, :b})
  end

  test "dual_create_ttl" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 500) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    :timer.sleep(600)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :c, 500) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :c})
    assert(KVStore.Storage.delete(:a) == :ok)
  end

  test "create_delete_create" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    assert(KVStore.Storage.delete(:a) == :ok)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :c, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :c})
  end

  test "create_delete_create_ttl" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 500) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    :timer.sleep(600)
    assert(KVStore.Storage.delete(:a) == :does_not_exist)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :c, 500) == :ok)
    assert(KVStore.Storage.delete(:a) == :ok)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "create_update" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    assert(KVStore.Storage.update(:a, :c, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :c})
  end

  test "create_update_ttl" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 500) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    assert(KVStore.Storage.update(:a, :c, 1000) == :ok)
    :timer.sleep(600)
    assert(KVStore.Storage.read(:a) == {:value, :c})
    :timer.sleep(500)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "create_delete_update" do
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.create(:a, :b, 0) == :ok)
    assert(KVStore.Storage.read(:a) == {:value, :b})
    assert(KVStore.Storage.delete(:a) == :ok)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
    assert(KVStore.Storage.update(:a, :c, 0) == :does_not_exist)
    assert(KVStore.Storage.read(:a) == :does_not_exist)
  end

  test "web_create" do
    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:post, "/a/b", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "b"
  end

  test "web_create_delete" do
    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:post, "/a/b", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "b"

    conn = conn(:delete, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404
  end

  test "web_create_update_delete" do
    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:post, "/a/b", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "b"

    conn = conn(:put, "/a/c", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.resp_body == "c"

    conn = conn(:delete, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

  end

  test "web_create_ttl" do
    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:post, "/a/b/500", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    :timer.sleep(600)

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404
  end

  test "web_create_update_delete_ttl" do
    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:post, "/a/b/500", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body == "b"

    conn = conn(:put, "/a/c/1000", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    :timer.sleep(600)

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.resp_body == "c"

    conn = conn(:delete, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 200

    conn = conn(:get, "/a", "") |> KVStore.Router.call(@opts)
    assert conn.state == :sent
    assert conn.status == 404

  end

end
