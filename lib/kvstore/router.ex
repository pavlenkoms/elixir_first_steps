defmodule KVStore.Router do
  use Plug.Builder
  require KVStore.Storage

  #plug Plug.Parsers, parsers: [:urlencoded, :multipart]

  #plug :match
  #plug :dispatch
  plug :process_req

  def process_req(%Plug.Conn{request_path: "/"} = conn, _opts) do
    send_resp(conn, 402, "You can request an empty key only for extra payment!")
  end
  def process_req(%Plug.Conn{path_info: path, method: method} = conn, _opts) do
    result =
      case method do
        "GET" ->
          [key | _] = path
          KVStore.Storage.read(key)
        "POST" ->
          try do
            [key, value| tail] = path
            ttl = get_ttl(tail)
            KVStore.Storage.create(key, value, ttl)
          catch
            c, e ->
              send_resp(conn, 400, "You are cause of error #{inspect c}:#{inspect e}")
          end
        "DELETE" ->
          [key | _] = path
          KVStore.Storage.delete(key)
        method when  method === "PUT" or method === "PATCH" ->
          try do
            [key, value| tail] = path
            ttl = get_ttl(tail)
            KVStore.Storage.update(key, value, ttl)
          catch
            c, e ->
              send_resp(conn, 400, "You are cause of error #{inspect c}: #{inspect e}")
          end
        _ ->
          :bad_method
      end
    case result do
      :ok -> send_resp(conn, 200, "Success")
      :already_exist -> send_resp(conn, 406, "yep! my personal laws don't allow it!")
      :does_not_exist -> send_resp(conn, 404, "key does not exist!")
      :bad_method -> send_resp(conn, 405, "some kind of unknown activity was there")
      {:value, value} -> send_resp(conn, 200, value)
      _ -> send_resp(conn, 500, "sorry, shit happens:-(")
    end
  end

  def get_ttl(list) do
    case list do
      [ttl | _] ->
        try do
          String.to_integer(ttl)
        catch
          _,_ -> 0
        end
      [] -> 0
    end
  end
end
