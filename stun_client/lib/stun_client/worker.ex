defmodule StunClient.Worker do
  use GenServer
  require Record
  require Logger

  @stun_server_ip       {13, 70, 200, 12}
  @stun_server_port     3478

  @stun_interval        :timer.seconds(10)
  @stun_request_timeout :timer.seconds(5)
  @stun_retry_count     2

  Record.defrecord(:stun, Record.extract(:stun, from_lib: "stun/include/stun.hrl"))

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(_args) do
    %{socket: socket, port: port} = open_stun_port()
    Logger.info("Opened STUN local port #{port}")

    schedule_reopen()
    {:ok, _tref} = :timer.send_interval(@stun_interval, :send_request)

    state = %{
      socket: socket,
      local_port: port,
      fail_count: 0,
      prev_trid: nil
    }
    {:ok, state}
  end

  @impl true
  def handle_info(:reopen_socket, state = %{fail_count: 0}) do
    {:noreply, reopen_socket(state)}
  end

  def handle_info(:reopen_socket, state) do
    schedule_reopen()
    {:noreply, state}
  end

  def handle_info(:send_request, state = %{socket: socket, fail_count: fail_count}) do
    trid =
      if fail_count > 0 do
        state.prev_trid
      else
        <<trid :: 96>> = :crypto.strong_rand_bytes(12)
        trid
      end

    Logger.info("Sending STUN request with TrID \"#{format_trid(trid)}\"")

    req = stun(method: 0x01, class: :request, trid: trid)
    bin = :stun_codec.encode(req)
    :ok = :gen_udp.send(socket, @stun_server_ip, @stun_server_port, bin)

    case :gen_udp.recv(socket, 0, @stun_request_timeout) do
      {:ok, {from_ip, from_port, resp_bin}} ->

        {:ok, resp} = :stun_codec.decode(resp_bin, :datagram)

        {mapped_ip, mapped_port} = stun(resp, :'XOR-MAPPED-ADDRESS')
        received_trid = stun(resp, :trid)

        Logger.info("Received STUN response from #{format_ip_port from_ip, from_port
                    } with mapped address #{format_ip_port(mapped_ip, mapped_port)
                    } with TrID \"#{format_trid(received_trid)}\"")

        {:noreply, %{state | fail_count: 0}}

      {:error, reason} ->
        new_fail_count = fail_count + 1
        if new_fail_count >= @stun_retry_count do
          Logger.error("Failed to receive #{new_fail_count
                       } consecutive STUN response for TrID \"#{format_trid(trid)
                       }\", reason: #{inspect reason}")
          new_state = reopen_socket(state)
          {:noreply, new_state}
        else
          Logger.warn("Failed to receive STUN response for TrID \"#{format_trid(trid)}\"")
          {:noreply, %{state | fail_count: new_fail_count, prev_trid: trid}}
        end
    end
  end

  def handle_info(msg, state) do
    Logger.warn("Received unexpected #{inspect msg} in state #{inspect state}")
    {:noreply, state}
  end

  #
  # Private
  #

  defp schedule_reopen do
    socket_reopen_interval = :timer.minutes(2) + :timer.seconds(:rand.uniform(60))
    :timer.send_after(socket_reopen_interval, :reopen_socket)
  end

  defp reopen_socket(state = %{socket: socket, local_port: port}) do
    :ok = :gen_udp.close(socket)
    %{socket: new_socket, port: new_port} = open_stun_port()
    Logger.info("Closed old STUN port #{port}, opened new STUN local port #{new_port}")
    schedule_reopen()
    %{state | socket: new_socket, local_port: new_port, fail_count: 0}
  end

  defp open_stun_port do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    {:ok, {ip, port}} = :inet.sockname(socket)
    %{socket: socket, ip: ip, port: port}
  end

  defp format_trid(trid) do
    trid_bin = <<trid :: 96>>
    trid_bytes = for <<c <- trid_bin>>,
      do: c |> Integer.to_string(16) |> String.pad_leading(2, "0")
    Enum.join(trid_bytes, ":")
  end

  defp format_ip_port({ip1, ip2, ip3, ip4}, port) do
    "#{ip1}.#{ip2}.#{ip3}.#{ip4}:#{port}"
  end
end
