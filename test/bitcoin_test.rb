require "minitest/autorun"
require "open3"
require "rbconfig"
require_relative "../bitcoin"

class BitcoinTest < Minitest::Test
  VERSION_HEX = "f9beb4d976657273696f6e0000000000550000002c2f86f3" \
                "7e1101000000000000000000c515cf61000000000000000000000000" \
                "00000000000000000000ffff2e13894a208d0000000000000000" \
                "00000000000000000000ffff7f000001208d00000000000000000000000000"
  VERACK_HEX = "f9beb4d976657261636b000000000000000000005df6e0e2"
  PING_HEX = "f9beb4d970696e67000000000000000008000000cd8d1acccc8df14f44709205"
  PONG_HEX = "f9beb4d9706f6e67000000000000000008000000cd8d1acccc8df14f44709205"

  def test_byte_helpers_and_fixed_wire_vectors
    assert_equal "55", hexadecimal(85)
    assert_equal "00000055", field(85, 4)
    assert_equal "55000000", reversebytes(size(hexadecimal(85), 4))
    assert_equal "76657261636b000000000000", ascii2hex("verack")
    assert_equal "5df6e0e2", checksum("")
    assert_equal "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456", hash256("")
    assert_equal VERSION_HEX, version_message
    assert_equal 109, [version_message].pack("H*").bytesize
  end

  def test_handshake_exchanges_frames_and_leaves_socket_open
    with_socket_pair do |socket, peer|
      peer.write([VERSION_HEX + VERACK_HEX].pack("H*"))

      output, = capture_io { assert_same socket, handshake(socket) }

      assert_equal VERSION_HEX + VERACK_HEX, peer.read(133).unpack1("H*")
      assert_includes output, "<-version"
      assert_includes output, "<-verack"
      assert_includes output, "Handshake complete. Socket remains open."
      refute socket.closed?
    end
  end

  def test_handshake_requires_an_existing_open_socket
    assert_raises(IOError) { handshake }
    with_socket_pair do |socket, _peer|
      socket.close
      assert_raises(IOError) { handshake(socket) }
    end
  end

  def test_receiver_finds_magic_bytes_and_replies_with_the_ping_payload
    with_socket_pair do |socket, peer|
      # A leading byte checks that the receiver can find an unaligned header.
      peer.write("\x00" + [PING_HEX].pack("H*"))
      peer.close_write

      output, = capture_io { receive_messages(socket) }

      assert_equal PONG_HEX, peer.read(32).unpack1("H*")
      assert_includes output, "<-ping"
      assert_includes output, "pong->"
      assert_includes output, "The node closed the connection. Receiving stopped."
      refute socket.closed?
    end
  end

  def test_receiver_rejects_a_bad_checksum_before_sending_pong
    with_socket_pair do |socket, peer|
      peer.write([PING_HEX.sub("cd8d1acc", "00000000")].pack("H*"))
      peer.close_write

      capture_io do
        error = assert_raises(IOError) { receive_messages(socket) }
        assert_includes error.message, "checksum does not match"
      end
      assert_raises(IO::WaitReadable) { peer.read_nonblock(1) }
    end
  end

  def test_receiver_handles_a_truncated_header
    with_socket_pair do |socket, peer|
      peer.write(["f9beb4d9"].pack("H*"))
      peer.close_write

      output, = capture_io { receive_messages(socket) }

      assert_includes output, "Receiving stopped: The node closed the connection"
      refute socket.closed?
    end
  end

  def test_handshake_reader_rejects_an_incomplete_read
    with_socket_pair do |socket, peer|
      peer.write("\xf9\xbe")
      peer.close_write

      assert_raises(EOFError) { receive_message(socket, "version") }
    end
  end

  def test_known_mining_nonce_reproduces_block_100000
    result = nil
    output, = capture_io { result = mine(274148111) }

    assert_equal "000000000003ba27aa200b1cecaad478d2b00432346c3f1f3986da1afd33e506", result
    assert_includes output, "Found a hash at or below the target."
  end

  def test_each_topic_loads_its_own_dependencies_without_starting_an_experiment
    {
      "connection" => %w[connect disconnect],
      "bytes" => %w[hexadecimal size reversebytes hash256 field ascii2hex checksum],
      "messages" => %w[receive_messages receive_message read_bytes checksum],
      "handshake" => %w[handshake version_message receive_message checksum],
      "mining" => %w[mine field reversebytes hash256],
      "bitcoin" => %w[connect handshake receive_messages mine disconnect]
    }.each do |file, methods|
      check = "abort 'Missing method' unless #{methods.inspect}.all? { |name| respond_to?(name, true) }"
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, "-r", File.expand_path("../#{file}", __dir__), "-e", check
      )

      assert status.success?, "#{file}.rb: #{stderr}"
      assert_empty stdout, "#{file}.rb should only define methods when required"
    end
  end

  private

  def with_socket_pair
    socket, peer = Socket.pair(:UNIX, :STREAM, 0)
    Timeout.timeout(2) { yield socket, peer }
  ensure
    socket.close if socket && !socket.closed?
    peer.close if peer && !peer.closed?
  end
end
