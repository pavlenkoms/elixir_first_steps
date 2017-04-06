# модуль супервизора не описанный в скелете
# хороший тон запускать приложение начиная с супервизора
# или чего либо супервизороподобного.
# так повелось в эрланге и я пока не вижу аргументов
# что в элексире не должно быть так
defmodule MainSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    children = [
      worker(KVStore.Storage, [KVStore.Storage]),
      Plug.Adapters.Cowboy.child_spec(:http, KVStore.Router, [], port: 8080)
    ]
    supervise(children, strategy: :one_for_one)
  end
end
