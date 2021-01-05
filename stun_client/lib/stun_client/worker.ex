defmodule StunClient.Worker do
  use GenStateMachine
  require Logger

  alias StunClient.Stun

  @stun_interval              :timer.seconds(10)
  @stun_retry_count           5
  @stun_reset_interval        :timer.minutes(2)
  @stun_reset_interval_random 60  # in seconds

  def start_link(args) do
    GenStateMachine.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    client_id = Keyword.get(args, :client_id)
    Logger.debug("Starting client #{client_id}")
    data = %{
      server_ip:   Keyword.get(args, :server_ip),
      server_port: Keyword.get(args, :server_port),
      client_id:   client_id,
      socket:      nil,
      local_port:  nil,
      fail_count:  0,
      trid:        nil,
      mapped_ip:   nil,
      mapped_port: nil
    }
    init_delay = :rand.uniform(@stun_interval)
    action = {{:timeout, :init}, init_delay, nil}
    {:ok, :init, data, action}
  end

  @impl true
  def handle_event({:timeout, :init}, _, :init, data) do
    new_data = reopen_socket(data)
    actions =
      [
        {{:timeout, :send_request}, 0, nil},
        {{:timeout, :reopen_socket}, socket_reopen_interval(), nil}
      ]
    {:next_state, :sending, new_data, actions}
  end

  def handle_event({:timeout, :reopen_socket}, _, :sending, data) do
    new_data =
      if data.fail_count > 0 do
        Logger.debug("Client #{data.client_id}: Not re-opening socket since failure count is #{data.fail_count}")
        data
      else
        Logger.debug("Client #{data.client_id}: Re-opening socket periodically, port: #{data.local_port}")
        reopen_socket(data)
      end
    action = {{:timeout, :reopen_socket}, socket_reopen_interval(), nil}
    {:keep_state, new_data, action}
  end

  def handle_event({:timeout, :reopen_socket}, _, _state, _data) do
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:timeout, :send_request}, _, :sending, data) do
    trid = if data.fail_count > 0, do: data.trid, else: gen_transaction_id()

    Logger.info("Client #{data.client_id}: Sending STUN request with TrID \"#{format_trid(trid)}\"")

    bin = trid |> Stun.make_stun_request() |> Stun.encode()
    :ok = :gen_udp.send(data.socket, data.server_ip, data.server_port, bin)

    new_data = %{data | trid: trid}
    action = {{:timeout, :send_request}, @stun_interval, nil}
    {:next_state, :waiting, new_data, action}
  end

  def handle_event(:info, {:udp, _socket, from_ip, from_port, bin}, :waiting, data) do
    {:ok, resp} = Stun.decode(bin)
    {mapped_ip, mapped_port} = Stun.get_mapped_address(resp)
    received_trid = Stun.get_transaction_id(resp)

    if received_trid != data.trid do
      Logger.warn("Client #{data.client_id}: Received STUN response with unexpected TrID \"#{format_trid(received_trid)}\"")
      :keep_state_and_data
    else
      Logger.info("Client #{data.client_id}: Received STUN response from #{format_ip_port(from_ip, from_port)
                  } with mapped address #{format_ip_port(mapped_ip, mapped_port)
                  } with TrID \"#{format_trid(received_trid)}\"")
      new_data = %{data | fail_count: 0, mapped_ip: mapped_ip, mapped_port: mapped_port}
      {:next_state, :sending, new_data}
    end
  end

  def handle_event({:timeout, :send_request}, _, :waiting, data) do
    new_fail_count = data.fail_count + 1
    if new_fail_count >= @stun_retry_count do
      Logger.error("Client #{data.client_id}: Failed to receive #{new_fail_count
                   } consecutive STUN response for TrID \"#{format_trid(data.trid)
                   }\", mapped addr: #{format_ip_port(data.mapped_ip, data.mapped_port)}")
      action = {{:timeout, :init}, 0, nil}
      {:next_state, :init, data, action}

    else
      Logger.warn("Client #{data.client_id}: Failed to receive STUN response for TrID \"#{format_trid(data.trid)
                  }\", mapped addr: #{format_ip_port(data.mapped_ip, data.mapped_port)}")
      new_data = %{data | fail_count: new_fail_count}
      {:next_state, :sending, new_data, :postpone}
    end
  end

  #
  # Private
  #

  defp reopen_socket(data = %{socket: nil}) do
    %{socket: socket, port: port} = open_stun_port()
    Logger.info("Client #{data.client_id}: Opened STUN local port #{port}")
    %{data | socket: socket, local_port: port}
  end

  defp reopen_socket(data = %{socket: socket, local_port: port}) do
    :ok = :gen_udp.close(socket)
    %{socket: new_socket, port: new_port} = open_stun_port()
    Logger.info("Client #{data.client_id}: Closed old STUN port #{port}, opened new STUN local port #{new_port}")
    %{data | socket: new_socket, local_port: new_port, fail_count: 0, mapped_ip: nil, mapped_port: nil}
  end

  defp open_stun_port do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: true])
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
  defp format_ip_port(ip, port) do
    "#{ip}:#{port}"
  end

  defp gen_transaction_id do
    <<trid :: 96>> = :crypto.strong_rand_bytes(12)
    trid
  end

  defp socket_reopen_interval do
    @stun_reset_interval + :timer.seconds(:rand.uniform(@stun_reset_interval_random))
  end
end
