defmodule Leader_election do
  # pick lowest process
  # processes wait to hear back
  # timeout  if nothing heard
  # when heard back pick leader
  # if wrong leader elected, Paxos will reject proposals, because not leader (if check)

  def start(name, participants) do
    pid = spawn(Leader_election, :init, [name, participants])

    Utils.register_name(Utils.add_to_name(name, "_LeaderElec"), pid)

    # case :global.re_register_name(Utils.add_to_name(name, "_LeaderElec"), pid) do
    #     :yes -> pid
    #     :no  -> :error
    # end
    # Process.link(pid)
    # IO.puts "registered #{name}"
    # pid
  end

  def init(name, participants) do
    state = %{
      name: Utils.add_to_name(name, "_LeaderElec"),
      # update to be paxos process name
      parent_name: name,
      participants: Enum.map(participants, fn n -> Utils.add_to_name(n, "_LeaderElec") end),
      alive: %MapSet{},
      leader: nil,
      timeout: 100
    }

    Process.send_after(self(), {:timeout}, 1000)

    run(state)
  end

  def run(state) do
    state =
      receive do
        {:timeout} ->
          # send heartbeat out to list of processes
          # Await using delay of timeout
          # sort the alive
          # Assign leader from list of replied processes
          # Clear the list

          # IO.puts("#{state.name}: #{inspect({:timeout})}")

          Utils.beb_broadcast(state.participants, {:heartbeat_req, self()})

          Process.send_after(self(), {:timeout}, state.timeout)

          state = elec_leader(state)

          %{state | alive: %MapSet{}}

        {:heartbeat_req, pid} ->
          # IO.puts("#{state.name}: #{inspect({:heartbeat_req, pid})}")
          send(pid, {:heartbeat_reply, state.parent_name})
          state

        {:heartbeat_reply, name} ->
          # IO.puts("#{state.name}: #{inspect {:heartbeat_reply, name}}")
          %{state | alive: MapSet.put(state.alive, name)}
      end

    run(state)
  end

  defp elec_leader(state) do
    # when more than 1 process is alive
    if MapSet.size(state.alive) > 0 do
      # sort the list and make the first element the leader
      first_elem = Enum.at(Enum.sort(state.alive), 0)
      # if first elem is already leader dont elect new leader
      if first_elem != state.leader do
        Utils.unicast(state.parent_name, {:leader_elect, first_elem})
        # the new leader is set
        %{state | leader: first_elem}
      else
        state
      end
    else
      state
    end
  end
end
