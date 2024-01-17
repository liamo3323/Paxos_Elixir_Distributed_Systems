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
      # name of the process
      name: name,
      # parent process application name
      parent_name: nil,
      # list of other processes in the network
      participants: participants,
      # leader process is updated in :leader_elect
      leader: nil,
      instance_state: %{},
      instance_decision: %{}
    }

    run(state)
  end

  def run(state) do
    # run stuff
    state =
      receive do
        {:leader_elect, first_elem} ->
          IO.puts("#{state.name} - Leader #{first_elem} is the new leader!")
          # called by leader_election.ex to tell parent process which process is leader
          state = %{state | leader: first_elem}

          if state.name == state.leader do
            Enum.reduce(Map.keys(state.instance_state), 0, fn x, acc ->
              Utils.beb_broadcast(
                state.participants,
                {:prepare, acc, state.instance_state[x].bal + 1, state.leader}
              )
            end)
          end

          state

        {:broadcast, instance_num, value, parent_process} ->
          state = %{state | parent_name: parent_process}

          IO.puts(
            "#{state.name} - with #{instance_num} has proposed #{inspect(value)} to the leader! "
          )

          Utils.beb_broadcast(state.participants, {:share_proposal, value, instance_num})
          state

        {:share_proposal, proposal, instance_num} ->
          state = check_instance_state_exist(state, instance_num)
          IO.puts("#{state.name} - has recieved a proposal of val: #{inspect(proposal)}")

          state =
            if state.instance_state[instance_num].v == nil do
              %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | v: proposal
                    })
              }
            else
              state
            end

          if state.name == state.leader do
            IO.puts(
              "#{state.name} - #{state.leader} has started a ballot! b-#{inspect(state.instance_state[instance_num].bal)}"
            )

            Utils.beb_broadcast(
              state.participants,
              {:prepare, instance_num, state.instance_state[instance_num].bal + 1, state.leader}
            )

            state
          else
            state
          end

        {:prepare, instance_num, b, leader_id} ->
          state = check_instance_state_exist(state, instance_num)

          if b > state.instance_state[instance_num].bal do
            IO.puts(
              "#{state.name} - sending a prepared to leader! | leader: #{inspect(leader_id)}"
            )

            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | bal: b
                  })
            }

            Utils.unicast(
              leader_id,
              {:prepared, instance_num, b, state.instance_state[instance_num].a_bal,
               state.instance_state[instance_num].a_val}
            )

            state
          else
            IO.puts(
              "#{state.name} - NACK SENT | b:#{inspect(b)} | bal #{inspect(state.instance_state[instance_num].bal)}"
            )

            Utils.unicast(leader_id, {:nack, b})
            state
          end

        {:prepared, instance_num, b, a_bal, a_val} ->
          state = check_instance_state_exist(state, instance_num)

          if state.name == state.leader and b == state.instance_state[instance_num].bal do
            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | quorums_prepared: state.instance_state[instance_num].quorums_prepared + 1,
                      a_val_list:
                        state.instance_state[instance_num].a_val_list ++ [{a_bal, a_val}]
                  })
            }

            if state.instance_state[instance_num].quorums_prepared >=
                 floor(length(state.participants) / 2) + 1 do
              IO.puts(
                "#{state.name} - Quorums Prepared Met! #{inspect(state.instance_state[instance_num].quorums_prepared)}"
              )

              {_, a_val} =
                Enum.reduce(state.instance_state[instance_num].a_val_list, {0, nil}, fn {k, v},
                                                                                        acc ->
                  {acc_k, acc_v} = acc

                  if k > acc_k and k != nil do
                    {k, v}
                  else
                    {acc_k, acc_v}
                  end
                end)

                #!
                IO.puts("#{state.name} - prepared - #{inspect(a_val)} | state instance v #{inspect(state.instance_state[instance_num].v)}")

              a_val =
                if a_val == nil do
                  state.instance_state[instance_num].v
                else
                  a_val
                end

              state = %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | quorums_prepared: 0,
                        v: a_val
                    })
              }

              IO.puts("#{state.name} - has sent to participants to accept")

              Utils.beb_broadcast(
                state.participants,
                {:accept, instance_num, b, state.instance_state[instance_num].v}
              )

              state
            else
              state
            end
          else
            state
          end

        {:accept, instance_num, b, v} ->
          state = check_instance_state_exist(state, instance_num)

          if b >= state.instance_state[instance_num].bal do
            IO.puts("#{state.name} - #{state.name} has accepted bal: #{b} | v: #{inspect(v)}")

            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | bal: b,
                      a_bal: b,
                      a_val: v
                  })
            }

            Utils.unicast(state.leader, {:accepted, instance_num, b})
            state
          else
            IO.puts("#{state.name} - NACK SENT")
            Utils.unicast(state.leader, {:nack, b})
            state
          end

        {:accepted, instance_num, b} ->
          state = check_instance_state_exist(state, instance_num)

          if state.name == state.leader do
            state = %{
              state
              | instance_state:
                  Map.put(state.instance_state, instance_num, %{
                    state.instance_state[instance_num]
                    | quorums_accepted: state.instance_state[instance_num].quorums_accepted + 1
                  })
            }

            if state.instance_state[instance_num].quorums_accepted >=
                 floor(length(state.participants) / 2) + 1 do
              IO.puts(
                "#{state.name} - Quorums Accepted Met! cnt: #{state.instance_state[instance_num].quorums_accepted}"
              )

              IO.puts(
                "#{state.name} is sending decision #{inspect(state.instance_state[instance_num].v)}"
              )

              Utils.beb_broadcast(
                state.participants,
                {:instance_decision, instance_num, state.instance_state[instance_num].v}
              )

              state = %{
                state
                | instance_state:
                    Map.put(state.instance_state, instance_num, %{
                      state.instance_state[instance_num]
                      | quorums_accepted: 0
                    })
              }

              state
            else
              state
            end
          else
            state
          end

        {:instance_decision, instance_num, decision} ->
          state = check_instance_state_exist(state, instance_num)

          state = %{
            state
            | instance_decision: Map.put(state.instance_decision, instance_num, decision)
          }

          IO.puts(
            "#{state.name} - Updated Map #{inspect(state.instance_decision)} | Parent: #{inspect(state.parent_name)}"
          )

          if state.parent_name != nil do
            send(state.parent_name, {:propose_responce, state.instance_state[instance_num].v})
          end

          state

        {:get_decision, instance_num, parent_process} ->
          # IO.puts("#{state.name} - trying to print a decision num #{instance_num}")
          if state.instance_decision[instance_num] != nil do
            send(
              parent_process,
              {:decision_responce, state.instance_decision[instance_num]}
            )
          end

          state

        # TODO missing instance nubmer
        {:nack, b} ->
          if state.name == state.leader and state.parent_name != nil do
            send(state.parent_name, {:abort, b})
          end

          state
      end

    run(state)
  end

  def check_instance_state_exist(state, instance_num) do
    if state.instance_state[instance_num] == nil do
      state = %{
        state
        | instance_state:
            Map.put(state.instance_state, instance_num, %{
              # the current ballot [a number]
              bal: 0,
              # accepted ballot
              a_bal: nil,
              # accepted ballot value
              a_val: nil,
              a_val_list: [],
              # proposal
              v: nil,
              quorums_prepared: 0,
              quorums_accepted: 0
            })
      }
    else
      state
    end
  end

  def get_decision(pid_pax, inst, t) do
    # takes the process identifier pid of a process running a Paxos replica, an instance identifier inst, and a timeout t in milliseconds

    # return v != nil if v is the value decided by consensus instance inst
    # return nil in all other cases

    send(pid_pax, {:get_decision, inst, self()})
    # send(pid_pax, {:get_decision, inst, t, self()})
    receive do
      {:decision_responce, v} ->
        # IO.puts("returning v in :decision_responce #{inspect(v)}")
        v
    after
      t -> nil
    end
  end

  def propose(pid_pax, inst, value, t) do
    # is a function that takes the process identifier
    # pid of an Elixir process running a Paxos replica, an instance identifier inst, a timeout t
    # in milliseconds, and proposes a value value for the instance of consensus associated
    # with inst. The values returned by this function must comply with the following
    send(pid_pax, {:broadcast, inst, value, self()})

    receive do
      {:propose_responce, v} ->
        IO.puts("returning v in :propose_responce #{inspect(v)}")
        v

      {:abort} ->
        {:abort}
    after
      t -> {:timeout}
    end
  end
end
