require "socket"
require "digest"
require "timeout"

def connect(host = "127.0.0.1", port = 8333)
  socket = TCPSocket.open(host, port)
  puts "Connected to #{host}:#{port}"
  return socket
end

# Handy functions for getting data in the right format for messages
def hexadecimal(number)
  return number.to_s(16)
end

def size(data, size)
  return data.rjust(size * 2, '0') # 2 hexadecimal characters = 1 byte
end

def reversebytes(bytes)
  return bytes.scan(/../).reverse.join() # reverse the order of whole bytes
end

def ascii2hex(string)
  # Convert each character to its hexadecimal byte representation
  bytes = string.each_byte.map { |c| c.to_s(16) }.join()

  # Pad up to 12 bytes, keeping the ASCII string on the left
  return bytes.ljust(24, '0')
end

def checksum(bytes)
  # Hash the raw bytes twice
  hash = Digest::SHA256.digest(Digest::SHA256.digest([bytes].pack("H*"))).unpack("H*")[0]

  # Return the first 4 bytes (8 hexadecimal characters)
  return hash[0...8]
end

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

def disconnect(socket)
  socket.close unless socket.closed?
  puts "Disconnected."
end

# Keep the Ruby process alive so you can issue more commands after the handshake.
if $PROGRAM_NAME == __FILE__
  require "irb"
  puts "Start: socket = connect; handshake(socket)"
  puts "When finished: disconnect(socket)"
  IRB.start
end
