
# # TASK 2 HANDLING
# def test(paxos_pid) do
#   propose = Paxos.propose(paxos_pid, :inst_1, :value_1, 1000)

#   handle(propose)
#  end

#  def handle({:abort}) do
#    1
#  end

#  def handle({:timeout}) do
#    2
#  end

#  def handle({:decision, v}) do
#   3
#  end

 # TASK 1
  defmodule Paxos do

    def start(name, participants) do
    # do spawn stuff

    # is a function that takes an atom name, and a list of
    # atoms participants as arguments. It spawns a Paxos process, registers it in the global
    # registry under the name name, and returns the identifier of the newly spawned process.
    # The argument participants must be assumed to include symbolic names of all
    # replicas (including the one specified by name) participating in the protocol.

      pid_pax = spawn(Paxos, :init, [name, participants])

      Utils.register_name(name, pid_pax, false)

    end

    def init(name, participants) do

      leader = Leader_election.start(name, participants)

      state = %{
        name: name, # name of the process
        parent_name: nil, # parent process application name
        participants: participants, # list of other processes in the network
        leader: nil, # leader process is updated in :leader_elect
        bal: 0, # the current ballot [a number]
        a_bal: nil, # accepted ballot
        a_val: nil, # accepted ballot value
        a_val_list: [],
        v: nil, # proposal
        instance_decision: %{}, # Map{instance_num -> decision [proposed value]}
        instance_num: nil,
        processes: nil,
        timedout: 5000,
        decided: false,
        quorums: 0 # counter for processes in a quorum for majority
      }
      run(state)
    end

    def run(state)do
    # run stuff
      state = receive do
        {:leader_elect, first_elem} ->
            IO.puts("#{state.name} - Leader #{first_elem} is the new leader!")
          # called by leader_election.ex to tell parent process which process is leader
          state = %{state | leader: first_elem}
          if state.name == state.leader and state.v != nil do
            state = %{state | bal: state.bal+1}
              IO.puts("#{state.name} - has sent prepared from leader_elect!")
            Utils.beb_broadcast(state.participants, {:prepare, state.bal, state.leader})
          end
          state

        {:broadcast, inst, value, t, parent_process} ->
          state = %{state | timedout: t, instance_num: inst, v: value, parent_name: parent_process}
            IO.puts("#{state.name} - with #{inst} has proposed #{inspect(value)} to the leader! Broad-Parent: #{inspect(state.parent_name)}")
          Utils.beb_broadcast(state.participants, {:share_proposal, state.v, state.instance_num})
          state

        {:share_proposal, proposal, instance_num} ->
            IO.puts("#{state.name} - has updated instance_num #{inspect(instance_num)}")
          state = %{state | instance_num: instance_num}
          IO.puts("#{state.name} - has recieved a proposal of val: #{inspect(proposal)}")
          if state.v == nil do
            state = %{state | v: proposal}
            IO.puts("#{state.name} - proposal recieved v: #{inspect(state.v)}")
            state
          else
            state
          end

          if state.name == state.leader do
              IO.puts("#{state.name} - #{state.leader} has started a ballot! ")
            state = %{state | bal: state.bal+1}
            Utils.beb_broadcast(state.participants, {:prepare, state.bal, state.leader})
            state
          else
            state
          end

        {:prepare, b, leader_id} ->
          if b > state.bal do
                IO.puts("#{state.name} - sending a prepared to leader! | leader: #{inspect(leader_id)}")
              state = %{state | bal: b}
              Utils.unicast(leader_id, {:prepared, state.bal, state.a_bal, state.a_val})
              state
          else
              IO.puts("#{inspect(state)}")
                IO.puts("#{state.name} - NACK SENT | b:#{inspect(b)} | bal #{inspect(state.bal)}")
              Utils.unicast(leader_id, {:nack, b})
              state
          end
          state

        {:prepared, b, a_bal, a_val} ->
          state = %{state | quorums: state.quorums+1}
          state = %{state | a_val_list: state.a_val_list++[{a_bal,a_val}]}
          if state.name == state.leader do
              if state.quorums > (length(state.participants)/2+1) do
                  IO.puts("#{state.name} - Quorum Met! #{inspect(state.quorums)}")
                  state = if Enum.map(state.a_val_list fn acc ->  end)

                  Enum.map('abc', fn num -> 1000 + num end)
                  [1097, 1098, 1099]

                  state = if a_val == nil do
                        IO.puts("#{state.name} - [a_val == nil] Setting v <- #{inspect(state.v)} ")
                      state = %{state | v: state.v, quorums: 0}
                      state
                  else
                        IO.puts("#{state.name} - [a_val != nil] Setting v <- #{inspect(a_val)} ")
                      state = %{state | v: a_val, quorums: 0}
                      state
                  end
                    IO.puts("#{state.name} - has sent to participants to accept")
                  Utils.beb_broadcast(state.participants, {:accept, b, state.v})
                  state
              else
                  state
              end
          else
              state
          end

        {:accept, b, v} ->
          if b >= state.bal do
                IO.puts("#{state.name} - #{state.name} has accepted bal: #{b} | v: #{inspect(v)}")
              state = %{state | bal: b, a_bal: b, a_val: v}
              Utils.unicast(state.leader, {:accepted, b})
              state
          else
                IO.puts("#{state.name} - NACK SENT")
              Utils.unicast(state.leader, {:nack, b})
              state
          end
          state

        {:accepted, b} ->
          if state.name == state.leader do
            state = %{state | quorums: state.quorums+1}
            if state.quorums > (length(state.participants)/2+1) do
                  IO.puts("#{state.name} - Quorum 2 Met! cnt: #{state.quorums}")
                state = %{state | decided: true}
                  IO.puts("#{state.name} is sending decision #{inspect(state.v)}")
                Utils.beb_broadcast(state.participants, {:instance_decision, state.v})
                state = %{state | quorums: 0}
                state
            else
                state
            end
          else
              state
          end

        {:instance_decision, decision} ->
          state = %{state | instance_decision: Map.put(state.instance_decision, state.instance_num, decision)}
            IO.puts("#{state.name} - Updated Map #{inspect(state.instance_decision)} | Parent: #{inspect(state.parent_name)}")
          if state.parent_name != nil do
              IO.puts("#{state.name} - sending to parent process #{inspect(state.parent_name)} value #{inspect(state.v)}")
            send(state.parent_name, {:propose_responce, state.v})
          end
          state

        {:get_decision, instance_num, t, parent_process} ->
          # IO.puts("#{state.name} - trying to print a decision num #{instance_num}")
          if Map.get(state.instance_decision, instance_num) != nil do
            send(parent_process, {:decision_responce, Map.get(state.instance_decision, instance_num)})
          else
            # IO.puts("instance decision not found!")
            send(parent_process, {:decision_responce, nil})
          end
          state

        {:nack, b} ->
          if state.name == state.leader do
              send(state.parent_name, {:nack, b})
          end
          state

        {:timeout, b} ->
            send(state.parent_name, {:timeout, b})
            state

      end
      run(state)
    end




    def get_decision(pid_pax, inst, t) do
      # takes the process identifier pid of a process running a Paxos replica, an instance identifier inst, and a timeout t in milliseconds

      # return v != nil if v is the value decided by consensus instance inst
      # return nil in all other cases

      Process.send_after(pid_pax, {:get_decision, inst, t, self()}, t)
      # send(pid_pax, {:get_decision, inst, t, self()})

      result = receive do {:decision_responce, v} ->
        # IO.puts("returning v in :decision_responce #{inspect(v)}")
        v
      end
    end

    def propose(pid_pax, inst, value, t) do

      # is a function that takes the process identifier
      # pid of an Elixir process running a Paxos replica, an instance identifier inst, a timeout t
      # in milliseconds, and proposes a value value for the instance of consensus associated
      # with inst. The values returned by this function must comply with the following


      Process.send_after(pid_pax, {:broadcast, inst, value, t, self()}, t)

      result = receive do {:propose_responce, v} ->
        IO.puts("returning v in :propose_responce #{inspect(v)}")
        v
      end
    end
  end
