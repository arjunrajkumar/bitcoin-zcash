require "irb"
require_relative "bytes"

# Recreate the mining calculation for historical block 100,000 locally.
# Run mine to start at zero, or mine(274148111) for the known winning nonce.
def mine(nonce = 0)
  unless nonce.is_a?(Integer) && nonce.between?(0, 0xffffffff)
    raise ArgumentError, "Nonce must be an integer between 0 and 4294967295."
  end

  # Target decoded from this block's bits field.
  target = '000000000004864c000000000000000000000000000000000000000000000000'

  # Block header fields from block 100,000.
  version    = '1'
  prevblock  = '000000000002d01c1fccc21636b607dfd930d31d01c3a62104612a1719011250'
  merkleroot = 'f3e94742aca4b5ef85488dc37c06c3282295ffec960994b2c0d5ac2a25a95766'
  time       = '1293623863' # 29 Dec 2010, 11:57:43 UTC
  bits       = '1b04864c'

  # Serialize the first 76 bytes; each attempt adds the four-byte nonce.
  header = reversebytes(field(version, 4)) + reversebytes(prevblock) + reversebytes(merkleroot) + reversebytes(field(time, 4)) + reversebytes(bits)

  puts "Mining example: block 100,000, starting at nonce #{nonce}. Press Ctrl-C to stop."
  puts "Target: #{target}"

  while nonce <= 0xffffffff
    # Hash the complete 80-byte header, then display the hash in Bitcoin's usual order.
    attempt = header + reversebytes(field(nonce, 4))
    result = reversebytes(hash256(attempt))

    puts "#{nonce}: #{result}"

    # Bitcoin accepts a hash below or equal to the target.
    if result.to_i(16) <= target.to_i(16)
      puts "Found a hash at or below the target."
      return result
    end

    nonce += 1
  end

  puts "No valid hash found before the four-byte nonce limit."
rescue Interrupt, IRB::Abort
  puts "\nStopped mining."
end
