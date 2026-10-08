require "timeout"
require_relative "connect"
require_relative "version"

# A closed connection returns nil (or fewer bytes), so check before unpacking.
def read_bytes(socket, count)
  bytes = socket.read(count)
  unless bytes && bytes.bytesize == count
    raise EOFError, "The node closed the connection while we were reading #{count} bytes."
  end
  return bytes
end

# Version and verack use the same 24-byte header format.
def receive_message(socket, expected_command)
  magic_bytes       = read_bytes(socket, 4)
  command_bytes     = read_bytes(socket, 12)
  size_bytes        = read_bytes(socket, 4)
  received_checksum = read_bytes(socket, 4)

  command = command_bytes.delete("\x00")
  payload_size = size_bytes.unpack1("V") # V = 32-bit unsigned, little-endian

  raise IOError, "Wrong network magic bytes." unless magic_bytes.unpack1("H*") == "f9beb4d9"
  unless command_bytes == [ascii2hex(expected_command)].pack("H*")
    raise IOError, "Expected #{expected_command}, received #{command.inspect}."
  end
  raise IOError, "Payload is too large." if payload_size > 4_000_000
  raise IOError, "Version payload is incomplete." if command == "version" && payload_size < 85
  raise IOError, "Verack must have an empty payload." if command == "verack" && payload_size != 0

  payload = read_bytes(socket, payload_size) # read(0) gives an empty string for verack
  unless checksum(payload.unpack1("H*")) == received_checksum.unpack1("H*")
    raise IOError, "The #{command} payload checksum does not match."
  end

  puts "<-#{command}"
  puts "magic_bytes: #{magic_bytes.unpack1('H*')}"
  puts "command:     #{command}"
  puts "size:        #{payload_size}"
  puts "checksum:    #{received_checksum.unpack1('H*')}"
  puts "payload:     #{payload.unpack1('H*')}"
  puts

  return payload
end

def perform_handshake(socket)
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
  puts "Handshake complete."
end

if $PROGRAM_NAME == __FILE__
  socket = nil
  begin
    # Run all four steps together, with a timeout if the node stops responding.
    Timeout.timeout(15) do
      socket = connect
      perform_handshake(socket)
    end
  rescue Timeout::Error
    warn "Handshake timed out after 15 seconds. Run the program again to reconnect."
    exit 1
  rescue IOError, SystemCallError, SocketError => error
    warn "Handshake failed: #{error.message}"
    exit 1
  rescue Interrupt
    puts "\nStopped."
  ensure
    socket.close if socket && !socket.closed?
  end
end
