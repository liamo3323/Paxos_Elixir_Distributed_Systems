
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

      # case :global.re_register_name(name, pid) do
      #     :yes -> pid
      #     :no  -> :error
      # end
      # IO.puts "registered #{name}"
      # pid

      Utils.register_name(name, pid_pax)

    end

    def init(name, participants) do

      leader = Leader_election.start(name, participants)

      state = %{
        name: name, # name of the process
        parent_name: Utils.add_to_name(name, "_Application"), # parent process application name
        participants: participants, # list of other processes in the network
        leader: nil, # leader process is updated in :leader_elect
        bal: 0, # the current ballot [a number]
        a_bal: nil, # accepted ballot
        a_val: nil, # accepted ballot value
        v: nil,
        your_proposal: nil, # proposal
        other_proposal: nil, # my backup
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
          if state.your_proposal != nil do
            Utils.beb_broadcast(state.participants, {:leader_broadcast, state.instance_num, state.your_proposal, state.timedout})
          end
          state

        {:leader_broadcast, inst, value, t} ->
          state = %{state | timedout: t, instance_num: inst, your_proposal: value}
          IO.puts("#{state.name} - has something to propose to the leader! ")
          if state.leader != nil do
              IO.puts("#{state.name} - A process has proposed something to #{state.leader}!")
            Utils.unicast(state.leader, {:broadcast, inst, value, t})
          else
            IO.puts("#{state.name} - Does not know the leader! ")
          end
          state


        {:broadcast, inst, value, t} ->
          Utils.beb_broadcast(state.participants, {:share_proposal, state.your_proposal})
          if state.name == state.leader do
                IO.puts("#{state.name} - #{state.leader} has started a ballot! ")
              Utils.beb_broadcast(state.participants, {:prepare, state.bal})
              state
          else
            state
          end

        {:share_proposal, proposal} ->
          if state.your_proposal == nil do
            state = %{state | your_proposal: proposal}
            state
          else
            state = %{state | other_proposal: proposal}
            state
          end

        {:prepare, b} ->
          if b+1 > state.bal do
                IO.puts("#{state.name} - #{state.name} has sent a prepared to leader! ")
              state = %{state | bal: b}
              Utils.unicast(state.leader, {:prepared, state.bal, state.a_bal, state.a_val})
              state
          else
                IO.puts("NACK SENT")
              Utils.unicast(state.leader, {:nack, b})
              state
          end

        {:prepared, b, a_bal, a_val} ->
          state = %{state | quorums: state.quorums+1}
          if state.name == state.leader do
              if state.quorums > (length(state.participants)/2+1) do
                  IO.puts("#{state.name} - Quorum Met! ")
                  if a_val == nil do
                      state = %{state | v: state.your_proposal, quorums: 0}
                      state
                  else
                      state = %{state | v: a_val, quorums: 0}
                      state
                  end
                    IO.puts("#{state.name} - #{state.name} has sent to participants to accept #{state.v}")
                  Utils.beb_broadcast(state.participants, {:accept, b, state.v})
                  state
              else
                  state
              end
          else
              state
          end




        {:accept, b, v} ->
          if b > state.bal do
                IO.puts("#{state.name} - #{state.name} has accepted #{b}")
              state = %{state | bal: b, a_bal: b, a_val: v}
              Utils.unicast(state.leader, {:accepted, b})
              state
          else
                IO.puts("#{state.name} - NACK SENT")
              Utils.unicast(state.leader, {:nack, b})
              state
          end

        {:accepted, b} ->
          if state.name == state.leader do
              if state.quorums > (state.participants/2+1) do
                    IO.puts("#{state.name} - Quorum 2 Met! ")
                  state = %{state | decided: true}
                  Utils.beb_broadcast(state.participants, {:instance_decision, state.v})
                  Utils.unicast(state.parent_name, {:decision, state.v})
                  state = %{state | quorums: 0}
                  state
              else
                  state
              end
          else
              state
          end

        {:instance_decision, decision} ->
          state = %{state | instance_decision: MapSet.put(state.instance_decision, state.instance, decision)}
          state

        {:nack, b} ->
          if state.name == state.leader do
              Utils.unicast(state.parent_name, {:nack, b})
              state
          else
            state
          end

        {:timeout, b} ->
            Utils.unicast(state.parent_name, {:timeout, b})
            state
      end
      run(state)
    end




    def get_decision(pid, inst, t) do
      # takes the process identifier pid of a process running a Paxos replica, an instance identifier inst, and a timeout t in milliseconds

      # return v != nil if v is the value decided by consensus instance inst
      # return nil in all other cases

      # 1 - internal used by paxos?

      # 2 - external: used by app

    end

    def propose(pid_pax, inst, value, t) do

      # is a function that takes the process identifier
      # pid of an Elixir process running a Paxos replica, an instance identifier inst, a timeout t
      # in milliseconds, and proposes a value value for the instance of consensus associated
      # with inst. The values returned by this function must comply with the following

      send(pid_pax, {:leader_broadcast, inst, value, t})

    end
  end
