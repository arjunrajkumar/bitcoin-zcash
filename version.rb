require 'digest' # needed for creating checksums

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

# Create the payload for a version message, using the tutorial's example values
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

puts message
