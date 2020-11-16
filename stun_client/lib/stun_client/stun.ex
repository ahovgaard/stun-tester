defmodule StunClient.Stun do
  require Record

  Record.defrecord(:stun, Record.extract(:stun, from_lib: "stun/include/stun.hrl"))

  def make_stun_request(transaction_id) do
    stun(method: 0x01, class: :request, trid: transaction_id)
  end

  def get_mapped_address(stun_resp_rec) do
    res = {_mapped_ip, _mapped_port} = stun(stun_resp_rec, :'XOR-MAPPED-ADDRESS')
    res
  end

  def get_transaction_id(stun_rec) do
    stun(stun_rec, :trid)
  end

  def encode(stun_rec) do
    :stun_codec.encode(stun_rec)
  end

  def decode(bin) do
    :stun_codec.decode(bin, :datagram)
  end
end
