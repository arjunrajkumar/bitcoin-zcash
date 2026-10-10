require "irb"
require_relative "bytes"

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

# Call this manually after handshake(socket). It reads messages and replies to pings.
def receive_messages(socket = nil)
  unless socket && !socket.closed?
    raise IOError, "Not connected. Run socket = connect first."
  end
  socket.getpeername

  puts "Receiving messages. Press Ctrl-C to return to the console."

  loop do
    buffer = ''

    # Look for the four magic bytes marking the next message.
    loop do
      byte = socket.read(1)
      if byte.nil?
        puts "The node closed the connection. Receiving stopped."
        return
      end

      buffer += byte.unpack1("H*")
      next unless buffer.size == 8 # 8 hexadecimal characters = 4 bytes

      if buffer == 'f9beb4d9'
        command_bytes     = read_bytes(socket, 12)
        command           = command_bytes.delete("\x00")
        payload_size      = read_bytes(socket, 4).unpack1("V")
        received_checksum = read_bytes(socket, 4).unpack1("H*")

        raise IOError, "Payload is too large." if payload_size > 4_000_000
        payload = read_bytes(socket, payload_size).unpack1("H*")
        unless checksum(payload) == received_checksum
          raise IOError, "The #{command.inspect} payload checksum does not match."
        end

        puts "<-#{command}"
        puts "magic_bytes: #{buffer}"
        puts "command:     #{command}"
        puts "size:        #{payload_size}"
        puts "checksum:    #{received_checksum}"
        puts "payload:     #{payload}"
        puts

        if command == "ping"
          pong_command  = ascii2hex("pong")
          pong_size     = reversebytes(size(hexadecimal(payload.length / 2), 4))
          pong_checksum = checksum(payload)
          pong_message  = "f9beb4d9" + pong_command + pong_size + pong_checksum + payload

          socket.write([pong_message].pack("H*"))
          puts "pong->"
          puts "magic_bytes: f9beb4d9"
          puts "command:     pong"
          puts "size:        #{payload.length / 2}"
          puts "checksum:    #{pong_checksum}"
          puts "payload:     #{payload}"
          puts
        end

        break # Finished one message; the outer loop starts the next one.
      end

      # Move forward one byte so magic bytes crossing a group boundary are found.
      buffer = buffer[2..-1]
    end
  end
rescue EOFError => error
  puts "Receiving stopped: #{error.message}"
rescue Interrupt, IRB::Abort
  puts "\nStopped receiving. Socket remains open."
end
