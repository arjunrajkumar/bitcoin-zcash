require "socket"

host = "127.0.0.1"
port = 8333

socket = TCPSocket.open(host, port)
puts "Connected to #{host}:#{port}"
