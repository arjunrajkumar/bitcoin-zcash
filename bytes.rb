require "digest/sha2"

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

# Convert hexadecimal text to raw bytes, then SHA256 twice.
def hash256(data)
  binary = [data].pack("H*")
  hash1 = Digest::SHA256.digest(binary)
  hash2 = Digest::SHA256.hexdigest(hash1)
end

# Pad a number's hexadecimal representation to the requested byte width.
def field(data, size)
  hex = data.to_i.to_s(16).rjust(size * 2, '0')
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
