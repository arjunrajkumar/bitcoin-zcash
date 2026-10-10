require "irb"
require_relative "bytes"
require_relative "connection"
require_relative "messages"
require_relative "handshake"
require_relative "mining"

# Keep the Ruby process alive so you can issue more commands after the handshake.
if $PROGRAM_NAME == __FILE__
  puts "Start: socket = connect; handshake(socket)"
  puts "Then: receive_messages(socket)"
  puts "When finished: disconnect(socket)"
  puts "Mining example: mine, or mine(274148111) to try the known winning nonce."
  IRB.start
end
