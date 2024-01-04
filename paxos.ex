
# TASK 2 HANDLING
def test(paxos_pid) do
  propose = Paxos.propose(paxos_pid, :inst_1, :value_1, 1000)

  handle(propose)
 end

 def handle({:abort}) do
   1
 end

 def handle({:timeout}) do
   2
 end

 def handle({:decision, v}) do
  3
 end


 # TASK 1
 defmodule Paxos do

   def start(name, participants) do
    # do spawn stuff

    # is a function that takes an atom name, and a list of
    # atoms participants as arguments. It spawns a Paxos process, registers it in the global
    # registry under the name name, and returns the identifier of the newly spawned process.
    # The argument participants must be assumed to include symbolic names of all
    # replicas (including the one specified by name) participating in the protocol.

      pid_pax = spawn(Paxos, :init, [name, participant])

      # case :global.re_register_name(name, pid) do
      #     :yes -> pid
      #     :no  -> :error
      # end
      # IO.puts "registered #{name}"
      # pid

      Utils.register_name(name, pid)

    end

    def init(name, participants) do

      state = %{
        name: name,
        parent_name: Utils.add_to_name(name, "_Application"),
        participants: participants,
        leader: nil, # leader process is updated in :leader_elect
        bal: 0, # the current ballot [a number]
        a_bal: nil, # accepted ballot
        a_val: nil, # accepted ballot value
        v: nil, # proposed value
        proposals: %MapSet{},
        processes: processes,
        timedout: 5000,
        decided: false,
        quorums: 0 # counter for processes in a quorum for majority
      }
      run(state)
    end

   def run(state)
    # run stuff
    state = receive do
      {:leader_elect, first_elem} ->
          # called by leader_election.ex to tell parent process which process is leader

          state = %{state | leader: first_elem}
          # b is the current ballot being proposed!
          Util.beb_broadcast(state.participants, {:prepare, state.bal})
          state

      {:broadcast} ->
         if state.name == state.leader do
            Util.beb_broadcast(state.participants, {:prepare, state.bal})
            state = %{state | proposals: MapSet.put(state.proposals, value)}
            state
         else
           state
         end

      {:prepare, b} ->
        # if b > bal then
        # bal := b
        # send (prepared, b, a_bal, a_val) to p
        # else
        # send (nack, b) to p

        if b > state.bal do
            state = %{state | bal: b}
            send(state.leader, {:prepared, state.b, state.a_bal, state.a_val})
            state
        else
            send(state.leader, {:nack, b})
            state
        end

      {:prepared, b, a_bal, a_val} ->
        # If all a_val = null:
          # V= v0;
        # else,
          # V := a_val with the highest a_bal in S;
        # Broadcast (accept, b, V)

        # Await all responce after 5 sec

        state = %{state | quorums: state.quorums+1}
        if state.name == state.leader do
            if state.quorums > (state.participants/2+1) do
                if a_val == null do
                    state = %{state | v: Enum.at{state.proposals, 0}}
                    state = %{state | quorums: 0}
                    state
                else
                    state = %{state | v: a_bal}
                    state = %{state | quorums: 0}
                    state
                end
            else
                state
            end
        else
            state
        end


        Util.beb_broadcast(state.participants, {:accept, b, state.v})
        state

      {:accept, b, v} ->
        # if b ≥ bal then
          # bal := b
          # (a_bal, a_val) := (b, v)
          # send (accepted, b) to p
        # else
          # send (nack, b) to p

        if b > state.bal do
            state = %{state | bal: b}
            state = %{state | a_bal: b}
            state = %{state | a_val: v}
            send(state.leader, {:accepted, b})
            state
        else
            send(state.leader, {:nack, b})
            state
        end

      {:accepted, b} ->
        # a value has been accepted and will be sent to the parent (application)

        if state.name == state.leader do
            if state.quorums > (state.participants/2+1) do
                state = %{state | decided: true}
                Util.unicast(state.parent_name, {:decision, state.v})
                state = %{state | quorums: 0}
                state
            else
                state
            end
        else
            state
        end

      {:nack, b} ->
        # abort?!

        if state.name == state.leader do
            Util.unicast(state.parent_name, {:nack, b})
            state
        else
           state
        end

      {:timeout, b} ->
        # timedout!

          Util.unicast(state.parent_name, {:timeout, b})
          state

    end
   end

   def get_decision(pid, inst, t) do
     # takes the process identifier pid of a process running a Paxos replica, an instance identifier inst, and a timeout t in milliseconds

     # return v != nil if v is the value decided by consensus instance inst
     # return nil in all other cases

   end

   def propose(pid, inst, value, t) do
    # do paxos stuff

    # is a function that takes the process identifier
    # pid of an Elixir process running a Paxos replica, an instance identifier inst, a timeout t
    # in milliseconds, and proposes a value value for the instance of consensus associated
    # with inst. The values returned by this function must comply with the following

        if state.timedout do
        {:timeout}

        # must be returned if the attempt to reach agreement initiated by
        # this propose call was unable to either decide or abort before the expiration of the
        # specified timeout t. This may happen e.g., if the Paxos process associated with
        # pid has crashed

        else

          if state.aborted do
          {:abort}

        # must be returned if an attempt to reach an agreement initiated by
        # this propose call was interrupted by another concurrent attempt with a higher
        # ballot. In this case, an application implemented on top of Paxos may choose to
        # reissue propose for this instance (e.g., if the invoking process is still considered
        # a leader).

          else
          {:decide, state.decided}

        # must be returned if the value v has been decided for the
        # instance inst. Note that v ≠ value is possible if a competing agreement
        # attempt was able to decide v ahead of the attempt initiated by this propose call.

          end
    end
end
