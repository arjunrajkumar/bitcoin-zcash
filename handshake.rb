require "timeout"
require_relative "bytes"
require_relative "messages"

def version_message
  # Create the payload using the tutorial's example values
  payload  = reversebytes(size(hexadecimal(70014), 4))      # protocol version
  payload += reversebytes(size(hexadecimal(0), 8))          # services
  payload += reversebytes(size(hexadecimal(1640961477), 8)) # time
  payload += reversebytes(size(hexadecimal(0), 8))          # remote node services
  payload += "00000000000000000000ffff2e13894a"             # remote node IP: 46.19.137.74
  payload += size(hexadecimal(8333), 2)                    # remote node port
  payload += reversebytes(size(hexadecimal(0), 8))          # local node services
  payload += "00000000000000000000ffff7f000001"             # local node IP: 127.0.0.1
  payload += size(hexadecimal(8333), 2)                    # local node port
  payload += reversebytes(size(hexadecimal(0), 8))          # nonce
  payload += "00"                                         # empty user agent
  payload += reversebytes(size(hexadecimal(0), 4))          # last block

  # Create the message header
  magic_bytes = 'f9beb4d9'
  command     = ascii2hex('version')
  size        = reversebytes(size(hexadecimal(payload.length / 2), 4))
  checksum    = checksum(payload)
  header      = magic_bytes + command + size + checksum

  # Combine the header and payload
  message = header + payload
  return message
end

# The caller owns the connection: handshake never opens or closes it.
def handshake(socket = nil)
  unless socket && !socket.closed?
    raise IOError, "Not connected. Run socket = connect first."
  end
  socket.getpeername # raises if an open socket has not been connected

  Timeout.timeout(15) do
    # 1. Send Version Message
    version = version_message
    socket.write([version].pack("H*")) # convert hexadecimal text to raw bytes
    puts "version->"
    puts version
    puts

    # 2. Receive Version Message
    receive_message(socket, "version")

    # 3. Receive Verack Message (version acknowledged)
    receive_message(socket, "verack")

    # 4. Send Verack Message
    payload     = '' # no payload: verack is just a message header
    magic_bytes = 'f9beb4d9'
    command     = ascii2hex('verack')
    size        = reversebytes(size(hexadecimal(payload.size / 2), 4))
    checksum    = checksum(payload)
    verack      = magic_bytes + command + size + checksum + payload

    socket.write([verack].pack("H*"))
    puts "verack->"
    puts "magic_bytes: #{magic_bytes}"
    puts "command:     verack"
    puts "size:        #{payload.size / 2}"
    puts "checksum:    #{checksum}"
    puts "payload:     #{payload}"
    puts
  end
  puts "Handshake complete. Socket remains open."
  return socket
end
