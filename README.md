# Bitcoin & Zcash

A small Ruby playground for exploring Bitcoin and Zcash: what they have in common, where they differ, and why those differences matter.

We're learning by building small experiments, inspecting the raw data, and adding one concept at a time. The aim is to understand what happens when nodes communicate, transactions are validated, and blocks are mined.

## What we're exploring

| Area | Questions we want to answer |
| --- | --- |
| Bytes and serialization | How are numbers, hashes, and messages represented? Where does byte order matter? |
| Networking | How do nodes connect, complete a handshake, and exchange messages? Which parts are shared between Bitcoin and Zcash? |
| Transactions | How are transactions constructed and validated? How do their formats and rules differ? |
| Mining and consensus | How do block headers, targets, and proof of work fit together? What changes between the two networks? |
| Privacy | What information can other people see? How do shielded transactions and zero-knowledge proofs work? |

## What's here so far

Each topic has its own small file. [`bitcoin.rb`](bitcoin.rb) loads them together and opens the same console, where you run commands manually:

- [Connect to a Bitcoin node and disconnect when finished.](connection.rb)
- [Build and exchange `version` and `verack` messages.](handshake.rb)
- [Receive messages, check their checksums, and reply to `ping` with `pong`.](messages.rb)
- [Explore hexadecimal, byte order, and double SHA256 hashing.](bytes.rb)
- [Reproduce the mining calculation for Bitcoin block 100,000.](mining.rb)

The implemented experiments are currently for Bitcoin. Zcash experiments and direct comparisons will be added as we learn. The Bitcoin handshake currently uses the tutorial's fixed example values, including its timestamp and advertised addresses.

## File map

| File | What it contains |
| --- | --- |
| [`connection.rb`](connection.rb) | `connect` and `disconnect` |
| [`handshake.rb`](handshake.rb) | `version_message` and `handshake` |
| [`messages.rb`](messages.rb) | Reading and checking messages, plus automatic pong replies |
| [`bytes.rb`](bytes.rb) | Shared hexadecimal, byte-order, hashing, and checksum helpers |
| [`mining.rb`](mining.rb) | The block 100,000 mining experiment |

Each file loads the dependencies it needs with `require` or `require_relative`. For example, both handshake and mining use helpers from `bytes.rb`. You can inspect or load a topic on its own; loading a file never connects, starts receiving, or starts mining. The console entry point is still `ruby bitcoin.rb`.

## Run the console

Requires Ruby with its bundled `socket`, `digest`, `timeout`, and `irb` libraries. Tested with Ruby 3.4.5.

```sh
git clone https://github.com/arjunrajkumar/bitcoin-zcash.git
cd bitcoin-zcash
ruby bitcoin.rb
```

If you already have the repository, run `ruby bitcoin.rb` from its directory. It opens an interactive console; you choose which experiment to run.

## Connect and listen

For this experiment, Bitcoin Core needs to be running separately and accepting mainnet P2P connections at `127.0.0.1:8333`.

Enter these commands in the Ruby console:

```ruby
socket = connect
handshake(socket)
receive_messages(socket)
```

`handshake` requires the socket returned by `connect`. It leaves the connection open. `receive_messages` prints incoming messages and automatically responds to pings.

Press **Ctrl-C** to stop receiving and return to the console. When finished:

```ruby
disconnect(socket)
```

## Try the mining example

This experiment runs locally without a socket connection. It uses the historical header fields from block 100,000 and prints each nonce and resulting hash.

To try the known successful nonce immediately:

```ruby
mine(274148111)
```

Expected hash:

```text
000000000003ba27aa200b1cecaad478d2b00432346c3f1f3986da1afd33e506
```

To start searching from zero:

```ruby
mine
```

Or start from another nonce with `mine(12345)`. Press **Ctrl-C** to stop and return to the console. Searching from zero and printing every attempt can take a long time.

The search stops when the hash is at or below the target, or when it reaches the four-byte nonce limit. It reproduces a historical calculation; it does not submit a new block or earn a mining reward.

## Run the offline checks

```sh
ruby test/bitcoin_test.rb
```

These checks use local socket pairs, without connecting to Bitcoin Core or a public peer. They cover the handshake, message checksums, ping/pong, disconnected reads, and the known block 100,000 hash. They require the `minitest` gem (`gem install minitest` if your Ruby installation does not include it).

## Learning reference

The initial Bitcoin networking and mining experiments follow [Learn Me A Bitcoin](https://learnmeabitcoin.com/), adapted into small commands we can run and inspect ourselves.
