
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

      case :global.re_register_name(name, pid) do
          :yes -> pid
          :no  -> :error
      end
      IO.puts "registered #{name}"
      pid

    end

   def init(name, processes) do

    state = %{
      name: name,
      processes: processes,
      timedout: timedout,
      aborted: aborted,
      decided: decided
    }
    run(state)
   end

   def run(state)
    # run stuff
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
