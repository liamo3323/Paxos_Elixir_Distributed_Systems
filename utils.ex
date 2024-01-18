defmodule Utils do
  def unicast(p, m) when p == nil, do: IO.puts("!!! Sending to nil with val #{inspect(m)}")

  def unicast(p, m) do
    case :global.whereis_name(p) do
      pid when is_pid(pid) -> send(pid, m)
      :undefined -> :ok
    end
  end

  # Best-effort broadcast of m to the set of destinations dest
  def beb_broadcast(dest, m), do: for(p <- dest, do: unicast(p, m))

  def add_to_name(name, to_add), do: String.to_atom(Atom.to_string(name) <> to_add)

  # \\ means default
  def register_name(name, pid, link \\ true) do
    case :global.re_register_name(name, pid) do
      :yes ->
        # parent runs this to link to leader + ERB
        # when one dies all links also die

        # if link true
        if link do
          Process.link(pid)
        end

        pid

      :no ->
        Process.exit(pid, :kill)
        :error
    end
  end
end
