
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
        instance_state: %{},
        instance_decision: %{},
        decided: false
      }

      # state = %{
      #   name: name, # name of the process
      #   parent_name: nil, # parent process application name
      #   participants: participants, # list of other processes in the network
      #   leader: nil, # leader process is updated in :leader_elect
      #   bal: 0, # the current ballot [a number]
      #   a_bal: nil, # accepted ballot
      #   a_val: nil, # accepted ballot value
      #   a_val_list: [],
      #   v: nil, # proposal
      #   instance_decision: %{}, # Map{instance_num -> decision [proposed value]}
      #   instance_num: nil,
      #   processes: nil,
      #   timedout: 5000,
      #   decided: false,
      #   quorums: 0 # counter for processes in a quorum for majority
      # }

      run(state)
    end

    def run(state)do
    # run stuff
      state = receive do
        {:leader_elect, first_elem} ->
            IO.puts("#{state.name} - Leader #{first_elem} is the new leader!")
          # called by leader_election.ex to tell parent process which process is leader
          state = %{state | leader: first_elem}
          # if state.name == state.leader and state.v != nil do
          #     IO.puts("#{state.name} - has sent prepared from leader_elect!")
          #   Utils.beb_broadcast(state.participants, {:prepare, state.bal+1, state.leader})
          # end
          state

        {:broadcast, instance_num, value, t, parent_process} ->
          state = %{state | parent_name: parent_process}
            IO.puts("#{state.name} - with #{instance_num} has proposed #{inspect(value)} to the leader! Broad-Parent: #{inspect(parent_process)}")
          Utils.beb_broadcast(state.participants, {:share_proposal, value, instance_num, t})
          state

        {:share_proposal, proposal, instance_num, timeout} ->
            IO.puts("#{state.name} - has updated instance_num #{inspect(instance_num)}")
          state = %{state | instance_state: Map.put(state.instance_decision, instance_num, %{
            bal: 0, # the current ballot [a number]
            a_bal: nil, # accepted ballot
            a_val: nil, # accepted ballot value
            a_val_list: [],
            v: nil, # proposal
            timeout: timeout,
            quorums: 0
          })}

          IO.puts("#{state.name} - has recieved a proposal of val: #{inspect(proposal)}")

          # state = if Map.get(state.instance_state, instance_num).v == nil do
          state = if state.instance_state[instance_num].v == nil do
            state = %{state | instance_state: Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]| v: proposal})}
              IO.puts("#{state.name} - proposal recieved v: #{inspect(state.instance_state[instance_num].v)}")
            state
          else
            state
          end

          if state.name == state.leader do
              IO.puts("#{state.name} - #{state.leader} has started a ballot! b-#{inspect(state.instance_state[instance_num].bal)}")
            Utils.beb_broadcast(state.participants, {:prepare, instance_num, state.instance_state[instance_num].bal+1, state.leader})
            state
          else
            state
          end

        {:prepare, instance_num, b, leader_id} ->
          if b > state.instance_state[instance_num].bal do
                IO.puts("#{state.name} - sending a prepared to leader! | leader: #{inspect(leader_id)}")
              state = %{state | instance_state: Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]| bal: b})}
              Utils.unicast(leader_id, {:prepared, instance_num, state.instance_state[instance_num].bal, state.instance_state[instance_num].a_bal, state.instance_state[instance_num].a_val})
                IO.puts("#{state.name} - sent prepared to #{leader_id}
                  b - #{state.instance_state[instance_num].bal} | a_bal - #{state.instance_state[instance_num].a_bal} | a_val - #{state.instance_state[instance_num].a_val} ")
              state
          else
              IO.puts("#{inspect(state)}")
                IO.puts("#{state.name} - NACK SENT | b:#{inspect(b)} | bal #{inspect(state.instance_state[instance_num].bal)}")
              Utils.unicast(leader_id, {:nack, b})
              state
          end
          state

        {:prepared, instance_num, b, a_bal, a_val} ->
          state = %{state | instance_state:
            Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
            quorums: state.instance_state[instance_num].quorums+1})}

            IO.puts("#{state.name} - Quorum: #{state.instance_state[instance_num].quorums}")

          state = %{state | instance_state:
            Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
            a_val_list: state.instance_state[instance_num].a_val_list++[{a_bal,a_val}]})}


          if state.name == state.leader do
              if state.instance_state[instance_num].quorums >= (floor(length(state.participants)/2)+1) do
                  IO.puts("#{state.name} -` Quorum Met! #{inspect(state.instance_state[instance_num].quorums)} state - #{inspect(state)}")

                  state = if Enum.all?(state.instance_state[instance_num].a_val_list, fn {k, v} -> v == nil end) do
                      IO.puts("#{state.name} - [a_val == nil] Setting v <- #{inspect(state.instance_state[instance_num].v)} ")

                    state = %{state | instance_state:
                      Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                      quorums: 0})}

                      #! v = v_0 <-- not sure
                    # state = %{state | instance_state:
                    #   Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                    #   v: a_val })}

                    state
                  else
                        IO.puts("#{state.name} - [a_val != nil] Setting v <- #{inspect(a_val)} ")
                      {a_bal, a_val} = Enum.reduce( state.instance_state[instance_num].a_val_list, {0, nil}, fn {k,v}, acc ->
                        {acc_k, acc_v} = acc
                        if k > acc_k and k != nil do
                          {k,v}
                        else
                          {acc_k, acc_v}
                        end
                      end)

                      state = %{state | instance_state:
                        Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                        quorums: 0})}

                      state = %{state | instance_state:
                        Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                        v: a_val, })}

                      state
                  end
                    IO.puts("#{state.name} - has sent to participants to accept")
                  Utils.beb_broadcast(state.participants, {:accept, instance_num, b, state.instance_state[instance_num].v})
                  state
              else
                  state
              end
          else
              state
          end

        {:accept, instance_num, b, v} ->
          if b >= state.instance_state[instance_num].bal do
                IO.puts("#{state.name} - #{state.name} has accepted bal: #{b} | v: #{inspect(v)}")

              state = %{state | instance_state:
                Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                bal: b, a_bal: b, a_val: v })}

              Utils.unicast(state.leader, {:accepted, instance_num, b})
              state
          else
                IO.puts("#{state.name} - NACK SENT")
              Utils.unicast(state.leader, {:nack, b})
              state
          end
          state

        {:accepted, instance_num, b} ->
          if state.name == state.leader do

            state = %{state | instance_state:
              Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
              quorums: state.instance_state[instance_num].quorums+1})}

            if state.instance_state[instance_num].quorums >= (floor(length(state.participants)/2)+1) do
                  IO.puts("#{state.name} - Quorum 2 Met! cnt: #{state.instance_state[instance_num].quorums}")
                state = %{state | decided: true}
                  IO.puts("#{state.name} is sending decision #{inspect(state.instance_state[instance_num].v)}")
                Utils.beb_broadcast(state.participants, {:instance_decision, instance_num, state.instance_state[instance_num].v})

                state = %{state | instance_state:
                  Map.put(state.instance_state, instance_num, %{state.instance_state[instance_num]|
                  quorums: 0})}

                state
            else
                state
            end
          else
              state
          end

        {:instance_decision, instance_num, decision} ->
          state = %{state | instance_decision: Map.put(state.instance_decision, instance_num, decision)}
            IO.puts("#{state.name} - Updated Map #{inspect(state.instance_decision)} | Parent: #{inspect(state.parent_name)}")
          if state.parent_name != nil do
              IO.puts("#{state.name} - sending to parent process #{inspect(state.parent_name)} value #{inspect(state.instance_state[instance_num].v)}")
            send(state.parent_name, {:propose_responce, state.instance_state[instance_num].v})
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
          if state.name == state.leader and state.parent_name != nil do
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
