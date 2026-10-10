require "socket"

def connect(host = "127.0.0.1", port = 8333)
  socket = TCPSocket.open(host, port)
  puts "Connected to #{host}:#{port}"
  return socket
end

def disconnect(socket)
  socket.close unless socket.closed?
  puts "Disconnected."
end
