defmodule StunClient.Utils do
  require Logger

  alias StunClient.Stun

  def open_stun_socket do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    {:ok, {ip, port}} = :inet.sockname(socket)
    Logger.info("Opening STUN socket with local IP #{inspect ip} and port #{port}")
    socket
  end

  def send_stun_request(socket, server_ip, server_port \\ 3478) do
    <<trid :: 96>> = :crypto.strong_rand_bytes(12)
    bin = trid |> Stun.make_stun_request() |> Stun.encode()
    Logger.info("Sendings STUN request with transaction ID #{trid}")
    :ok = :gen_udp.send(socket, server_ip, server_port, bin)
  end

  def await_stun_response(socket, timeout \\ 1_000) do
    with {:ok, {from_ip, from_port, bin}} <- :gen_udp.recv(socket, 0, timeout),
         {:ok, resp} <- Stun.decode(bin) do
      {mapped_ip, mapped_port} = Stun.get_mapped_address(resp)
      received_trid = Stun.get_transaction_id(resp)
      Logger.info("Received STUN response from #{inspect from_ip} port #{from_port
                  } with mapped address #{inspect mapped_ip}:#{mapped_port
                  } with transaction ID #{received_trid}")
    else
      err ->
        Logger.error("Failed to get STUN response: #{inspect err}")
        err
    end
  end
end
