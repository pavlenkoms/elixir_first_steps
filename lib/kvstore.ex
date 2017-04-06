defmodule KVstore do
  use Application

  def start(_type, _args) do
    MainSupervisor.start_link()
  end
end
