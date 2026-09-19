extends Node
## THE LAN SMOKE — ONE WHOLE SGManalink DUEL BETWEEN TWO GODOT PROCESSES
## over the ENCRYPTED LAN PATH, played headlessly and reported in numbers.
## Run it with `./tools/lan_smoke.sh` (the manual is in that file); this
## file is the half that hosts, joins and plays.
##
##   ../tools/godot --headless --path . res://tools/lan_smoke.tscn -- \
##       --role host --invite /tmp/lan/invite.txt
##   ../tools/godot --headless --path . res://tools/lan_smoke.tscn -- \
##       --role guest --invite /tmp/lan/invite.txt
##
## IT IS A SCENE, NOT A `-s` SCRIPT, and that is load-bearing: Godot
## registers the autoloads AFTER it loads a `--script` main loop, so a
## `-s` tool naming `SgLocalServer` never compiles ("Identifier not
## found: CardPacks", reproduced 2026-09-17). A main scene is loaded
## after them, so everything the game's own code expects is there.
##
## WHY THIS EXISTS. `tests/ui/test_sgmanalink_*.gd` already drive real
## sockets, real TLS and a real referee — but all of it inside ONE
## process, where the host object and the guest object share a frame, a
## card registry, a settings file and a clock. Nothing had ever checked
## that a SECOND copy of the game, with its own `user://`, can find this
## one over UDP, pin its certificate from a pasted invitation, sit down
## at the table and play a duel to a winner. That is the last step before
## carrying the build to a second computer, and this is the rehearsal of
## it a single machine can hold.
##
## WHAT IT IS NOT. It is not the same-computer `ws://` fallback (Host
## Game > Same-computer testing). The host binds a private IPv4 address,
## generates its RSA key and self-signed certificate, advertises on UDP
## 17898 and accepts `wss://` only; the guest searches the LAN, matches
## the advertised address/port/fingerprint against the invitation exactly
## as the Game Browser does, and connects with that one pinned
## certificate. Both seats are played by `tests/support/sg_network_pilot.gd`
## — the coverage pilot, not an `AiPlayer` difficulty — from the seat DTO
## the referee sent it, so every click crosses the wire.
##
## THE SEQUENCE, and every step prints a `LAN` line with its own timing:
##   host   start_lan -> invitation written -> connect to itself -> host a
##          room -> deck -> ready -> play seat 0 -> leave -> stop service
##   guest  search the LAN -> read the invitation -> cross-check the
##          discovered host against it -> connect -> join -> deck -> ready
##          -> one mulligan -> play seat 1 -> ONE MID-GAME DISCONNECT and
##          a reconnect -> play on to the winner -> watch the host leave
##          and the service stop
##
## EXIT CODES: 0 when the whole sequence ran and every check held; 1 when
## a check failed (every failure prints `LAN FAIL`); 2 when the run hit
## its `--deadline` with the duel unfinished; 3 for a bad argument.

const PILOT := "res://tests/support/sg_network_pilot.gd"
const DEFAULT_HOST_DECK := "res://decks/white_knights.deck"
const DEFAULT_GUEST_DECK := "res://decks/black_red_raiders.deck"
## Protocol 21 requires an explicit table deck rule even for bring-your-own.
const HOST_ACTION := {"op": "host", "name": "LAN smoke duel", "decks": "own", "deck": {}}
## A whole seat's turn can need a dozen commands (prepare, autopay,
## submit); this is the ceiling on one duel, not a target.
const MAX_COMMANDS := 4000
## How long the broadcast sweep is given before the directed query takes
## over. See [method _search] for why one computer needs that fallback.
const BROADCAST_SWEEP_MS := 6000

var role := ""
var address := ""
var port := 0
var invite_path := ""
var deck_path := ""
var nickname := ""
var seed_value := -1
var drop_turn := -1
var drop_ms := 2500
var discovery := true
var deadline_s := 600.0
var pace_ms := 25
var fps := 120
var verbose := false

var _exit_code := 3
var _started := 0.0
var _deadline_at := 0.0
var _failures := 0
var _server: SgLocalServer
var _client: SgLocalClient
var _scanner: SgLanDiscovery
var _pilot: RefCounted
var _metered: MeteredServer
var _refusals: Array[String] = []
var _round_trips: Array[int] = []
var _next_send_ms := 0
var _largest_command := 0


## The referee with a chosen seed and a tape measure on everything it
## sends. Both are host-process fixtures: no wire command can reach them.
class MeteredServer extends SgLocalServer:
	var chosen_seed := -1
	var largest: Dictionary = {}
	func _create_match(decks: Array, names: Array) -> SgPracticeMatch:
		return SgPracticeMatch.new(chosen_seed, decks, names)
	func _send(id: int, message: Dictionary) -> void:
		var kind := String(message.get("type", "?"))
		largest[kind] = maxi(int(largest.get(kind, 0)), SgProtocol.encode(message).length())
		super._send(id, message)


func _ready() -> void:
	if not _parse_args():
		get_tree().quit(_exit_code)
		return
	Engine.max_fps = fps
	_started = Time.get_ticks_msec()
	_deadline_at = _started + deadline_s * 1000.0
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _deadline_at > 0.0 and Time.get_ticks_msec() >= _deadline_at:
		_deadline_at = 0.0
		_say("deadline %.0fs reached; the run did not finish" % deadline_s)
		_report()
		get_tree().quit(2)


func _parse_args() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		var value := args[i + 1] if i + 1 < args.size() else ""
		match arg:
			"--role":
				role = value
				i += 1
			"--address":
				address = value
				i += 1
			"--port":
				if not value.is_valid_int() or int(value) < 0 or int(value) > 65535:
					return _bad("--port takes 0-65535, not '%s'" % value)
				port = int(value)
				i += 1
			"--invite":
				invite_path = value
				i += 1
			"--deck":
				deck_path = value
				i += 1
			"--name":
				nickname = value
				i += 1
			"--seed":
				if not value.is_valid_int():
					return _bad("--seed takes a whole number, not '%s'" % value)
				seed_value = int(value)
				i += 1
			"--drop-turn":
				if not value.is_valid_int() or int(value) < 0:
					return _bad("--drop-turn takes a whole number >= 0, not '%s'" % value)
				drop_turn = int(value)
				i += 1
			"--drop-ms":
				if not value.is_valid_int() or int(value) < 0:
					return _bad("--drop-ms takes milliseconds >= 0, not '%s'" % value)
				drop_ms = int(value)
				i += 1
			"--deadline":
				if not value.is_valid_float() or float(value) <= 0.0:
					return _bad("--deadline takes seconds > 0, not '%s'" % value)
				deadline_s = float(value)
				i += 1
			"--pace-ms":
				if not value.is_valid_int() or int(value) < 0:
					return _bad("--pace-ms takes milliseconds >= 0, not '%s'" % value)
				pace_ms = int(value)
				i += 1
			"--fps":
				if not value.is_valid_int() or int(value) < 0:
					return _bad("--fps takes a whole number >= 0, not '%s'" % value)
				fps = int(value)
				i += 1
			"--no-discovery":
				discovery = false
			"--verbose":
				verbose = true
			"--help", "-h":
				print(_usage())
				_exit_code = 0
				return false
			_:
				push_error("lan smoke: unknown argument %s\n%s" % [arg, _usage()])
				return false
		i += 1
	if role not in ["host", "guest"]:
		return _bad("--role must be host or guest")
	if invite_path.is_empty():
		return _bad("--invite needs the file both processes hand the invitation over in")
	if deck_path.is_empty():
		deck_path = DEFAULT_HOST_DECK if role == "host" else DEFAULT_GUEST_DECK
	if nickname.is_empty():
		nickname = "LAN host" if role == "host" else "LAN guest"
	if drop_turn < 0:
		# The guest is the seat that loses its network; the host is the
		# referee, and a referee that walks away is step (e), not step (d).
		drop_turn = 0 if role == "host" else 4
	if address.is_empty():
		var found := SgLanInvite.local_addresses()
		if found.is_empty():
			return _bad("no private IPv4 address on this computer; pass --address")
		address = found[0]
	return true


func _bad(why: String) -> bool:
	push_error("lan smoke: %s\n%s" % [why, _usage()])
	return false


static func _usage() -> String:
	return """lan_smoke.gd -- --role host|guest --invite PATH [options]
  --role        which half of the pair this process is (required)
  --invite      the file the host writes its invitation to and the guest
                reads it from — the stand-in for a privately sent message
  --address     the private IPv4 to host on / expect (default: the first
                LAN address this computer has)
  --port        gameplay TCP port (default 0: the host takes a free one
                and the invitation carries it)
  --deck        res:// deck for this seat
  --name        temporary display name (up to 20 characters)
  --seed        the referee's RNG seed, so a duel replays (host only)
  --drop-turn   disconnect once when the duel reaches this turn (the
                guest's default is 4, the host's is 0: never)
  --drop-ms     guest: how long the disconnect lasts (default 2500)
  --no-discovery  skip UDP: the host does not advertise, the guest does
                not search, and the invitation alone connects them
  --pace-ms     floor under the gap between this seat's commands (25).
                One command at a time makes the round trip the send rate,
                and the host drops a peer over 64 messages a second
  --deadline    whole-run guard in seconds (default 600)
  --fps         frame cap, which is also the network poll rate (default
                120; 0 is uncapped and spins a whole core)
  --verbose     print every command and every state revision
Exit 0: the sequence ran and every check held. 1: a check failed.
2: the deadline passed with the duel unfinished. 3: a bad argument."""


## One line, one fact, with milliseconds since the process started. The
## two logs are read side by side, so the role is on every line.
func _say(text: String) -> void:
	print("LAN %-5s %7.0fms  %s" % [role, Time.get_ticks_msec() - _started, text])


func _fail(text: String) -> void:
	_failures += 1
	print("LAN FAIL %s: %s" % [role, text])


func _check(condition: bool, text: String) -> bool:
	if not condition:
		_fail(text)
	return condition


## Wait for [param predicate], polling once a frame. False means the wait
## ran out, and that is a failure the caller reports in its own words.
func _until(predicate: Callable, budget_ms := 30000) -> bool:
	var until := Time.get_ticks_msec() + budget_ms
	while Time.get_ticks_msec() < until:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


## One command, and the round trip it took: the client holds input until
## the acknowledgement AND the snapshot that follows it have both landed,
## so this measures exactly what a player's click waits for.
func _act(action: Dictionary) -> bool:
	# THE HOST'S ABUSE LIMIT IS 64 MESSAGES A SECOND and this client sends
	# one command at a time, so the round trip IS the send rate — 16 ms
	# round trips measured here are 62 a second, one short of a drop.
	# `--pace-ms` is the floor that keeps a fast computer under it.
	while Time.get_ticks_msec() < _next_send_ms:
		await get_tree().process_frame
	_next_send_ms = Time.get_ticks_msec() + pace_ms
	var sent := Time.get_ticks_msec()
	if not _check(_client.command(action), "command %s refused locally: %s" % [action.op, _client.command_error]):
		return false
	_largest_command = maxi(_largest_command, _client._pending_wire.length())
	if not await _until(func() -> bool: return not _client.busy(), 30000):
		_fail("command %s never completed (status: %s)" % [action.op, _client.status])
		return false
	_round_trips.append(Time.get_ticks_msec() - sent)
	if verbose:
		_say("command %s took %dms, room revision %d" % [action.op,
			_round_trips.back(), int(_client.state.room.get("revision", 0))])
	return true


func _deck() -> Dictionary:
	var deck := DeckList.load_file(deck_path)
	if not deck.errors.is_empty():
		_fail("deck %s: %s" % [deck_path, deck.errors])
		return {}
	return {"name": deck.deck_name, "cards": Array(deck.cards), "sideboard": Array(deck.sideboard)}


func _run() -> void:
	_pilot = load(PILOT).new()
	_client = SgLocalClient.new()
	_client.refused.connect(func(reason: String) -> void:
		_refusals.append(reason)
		_fail("the referee refused a command: %s" % reason))
	add_child(_client)
	if role == "host":
		await _host()
	else:
		await _guest()
	_report()
	get_tree().quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------- host --

func _host() -> void:
	var service := MeteredServer.new()
	service.chosen_seed = seed_value
	add_child(service)
	_server = service
	_metered = service
	var started := Time.get_ticks_msec()
	# This probe's private-invitation contract is deliberate; open tables
	# advertise their invitation by design and are covered by the UI suite.
	var result := service.start_lan(address, port, discovery, nickname, SgLanDiscovery.PORT, false)
	if not _check(result == OK, "start_lan(%s:%d) failed with %d" % [address, port, result]):
		return
	_say("hosting wss://%s:%d, took %dms" % [service.lan_address, service.port, Time.get_ticks_msec() - started])
	if discovery:
		if service.discovery_error == OK:
			_say("advertising on UDP %d" % SgLanDiscovery.PORT)
		else:
			_say("NOTE discovery port %d is busy (error %d); the invitation still connects" % [
				SgLanDiscovery.PORT, service.discovery_error])
	var invitation := service.invitation()
	if not _check(invitation.begins_with(SgLanInvite.PREFIX), "the host produced no invitation"):
		return
	_say("invitation is %d characters, certificate fingerprint %s" % [invitation.length(),
		SgLanInvite.parse(invitation).fingerprint.substr(0, 16)])
	if not _write_invitation(invitation):
		return
	if not await _connect(invitation):
		return
	if not await _act(HOST_ACTION.duplicate(true)):
		return
	_say("room %s open" % String(_client.state.room.get("id", "?")))
	var deck := _deck()
	if deck.is_empty():
		return
	if not await _act({"op": "deck", "name": deck.name, "cards": deck.cards, "sideboard": deck.sideboard}):
		return
	_say("deck '%s' (%d cards) submitted" % [deck.name, deck.cards.size()])
	# The referee clears both Ready flags whenever a deck or an opponent
	# changes, so the room host readies LAST — exactly the order the
	# waiting room's two players fall into by themselves.
	if not await _until(func() -> bool: return int(_client.state.room.get("seat", -1)) == 0 \
		and _client.state.room.connected[1] and _client.state.room.ready[1], 120000):
		_fail("no guest ever joined and readied (room: %s)" % _client.state.room)
		return
	_say("guest '%s' joined with deck '%s' and is ready" % [String(_client.state.room.names[1]),
		String(_client.state.room.deck_names[1])])
	if not await _act({"op": "ready", "value": true}):
		return
	await _play(0)
	# The guest needs one more snapshot with the result in it before the
	# table goes away; a real host reads the end-of-duel window first.
	await _until(func() -> bool: return false, 1500)
	if not _client.state.room.is_empty() and not await _act({"op": "leave"}):
		return
	_say("host left the room")
	await _until(func() -> bool: return false, 1500)
	service.stop()
	_say("host service stopped; every invitation it issued is now dead")
	await _until(func() -> bool: return false, 3000)


func _write_invitation(invitation: String) -> bool:
	# Written beside the final name and renamed, so a guest polling for
	# the file can never read half an invitation.
	var temporary := invite_path + ".part"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not _check(file != null, "cannot write %s" % temporary):
		return false
	file.store_string(invitation)
	file.close()
	if not _check(DirAccess.rename_absolute(temporary, invite_path) == OK,
		"cannot rename %s to %s" % [temporary, invite_path]):
		return false
	_say("invitation handed over in %s" % invite_path)
	return true


# --------------------------------------------------------------- guest --

func _guest() -> void:
	var invitation := await _read_invitation()
	if invitation.is_empty():
		return
	var parsed := SgLanInvite.parse(invitation)
	if not _check(not parsed.is_empty(), "the invitation did not parse"):
		return
	_say("invitation parsed: %s:%d, fingerprint %s" % [parsed.address, int(parsed.port),
		String(parsed.fingerprint).substr(0, 16)])
	if discovery and not await _search(parsed):
		return
	if not await _connect(invitation):
		return
	if not await _until(func() -> bool: return not _open_room().is_empty(), 120000):
		_fail("no open room ever appeared in the game browser")
		return
	var room: Dictionary = _open_room()
	_say("game browser lists room '%s' hosted by %s" % [room.name, room.host])
	if not await _act({"op": "join", "room": room.id}):
		return
	var deck := _deck()
	if deck.is_empty():
		return
	if not await _act({"op": "deck", "name": deck.name, "cards": deck.cards, "sideboard": deck.sideboard}):
		return
	_say("deck '%s' (%d cards) submitted" % [deck.name, deck.cards.size()])
	if not await _act({"op": "ready", "value": true}):
		return
	await _play(1)
	await _watch_host_close()


func _read_invitation() -> String:
	if not await _until(func() -> bool: return FileAccess.file_exists(invite_path), 120000):
		_fail("the host never wrote %s" % invite_path)
		return ""
	var text := FileAccess.get_file_as_string(invite_path).strip_edges()
	_say("read a %d-character invitation from %s" % [text.length(), invite_path])
	return text


## The Game Browser's own two steps: find the host over UDP, then refuse
## to join it unless its advertised address, port and certificate
## fingerprint are the ones inside the privately shared invitation.
##
## THE SWEEP IS A BROADCAST, AND A COMPUTER DOES NOT HEAR ITS OWN.
## Reproduced on Linux over Wi-Fi, 2026-09-17: a datagram this machine
## sends to 255.255.255.255 — or to its own subnet broadcast — never
## comes back to a socket on this machine, so the one-computer rehearsal
## cannot see its own advert that way. That is the network's answer, not
## the game's: `Find LAN games` between two real computers is the part
## only two computers can test. Everything else in discovery — the query,
## the reply, the advert's contents, what it must NOT carry and the
## fingerprint match — is exercised by a query addressed straight at the
## host's own LAN address, which is what this does when the sweep is
## silent. A player whose sweep stays empty — guest Wi-Fi, a separated
## subnet, client isolation — has the same answer from the other end: the
## invitation carries the address, and `--no-discovery` is that run.
func _search(parsed: Dictionary) -> bool:
	_scanner = SgLanDiscovery.new()
	add_child(_scanner)
	var started := Time.get_ticks_msec()
	if not _check(_scanner.scan() == OK, "cannot scan this network"):
		return false
	var key := "%s:%d" % [parsed.address, int(parsed.port)]
	if await _until(func() -> bool: return _scanner.hosts.has(key), BROADCAST_SWEEP_MS):
		_say("broadcast sweep answered in %dms" % (Time.get_ticks_msec() - started))
	else:
		_say("NOTE the broadcast sweep found nothing in %dms: this computer does not receive its own LAN broadcasts, so `Find LAN games` needs the second computer. Asking %s directly instead." % [
			BROADCAST_SWEEP_MS, parsed.address])
		var directed := Time.get_ticks_msec()
		while Time.get_ticks_msec() - directed < 20000 and not _scanner.hosts.has(key):
			# Twice a second, well inside the host's sixteen replies.
			_scanner.query(parsed.address)
			await _until(func() -> bool: return _scanner.hosts.has(key), 500)
		if not _scanner.hosts.has(key):
			_fail("the host never answered a directed discovery query at %s:%d" % [
				parsed.address, SgLanDiscovery.PORT])
			return false
		_say("directed query answered in %dms" % (Time.get_ticks_msec() - directed))
	var advert: Dictionary = _scanner.hosts[key].host
	_say("found '%s' at %s:%d — %d open room(s), build %s" % [advert.name,
		advert.address, int(advert.port), int(advert.rooms), JSON.stringify(advert.stamp)])
	_check(not JSON.stringify(_scanner.hosts).contains(String(parsed.access)),
		"the discovery reply carried the access secret")
	_check(advert.access == "invitation" and not advert.has("invitation"),
		"the private host advertised its invitation")
	_check(advert.fingerprint == parsed.fingerprint,
		"the advertised certificate fingerprint is not the invitation's")
	_scanner.stop()
	return _failures == 0


func _open_room() -> Dictionary:
	for room: Dictionary in _client.state.get("rooms", []):
		if room.open:
			return room
	return {}


## (e) The host leaves the table and then stops its service. Both must
## reach this seat as something a player can read, not as a hang.
func _watch_host_close() -> void:
	if await _until(func() -> bool: return not _client.state.room.is_empty() \
		and not _client.state.room.connected[0], 20000):
		_say("host seat is now '%s', connected=%s" % [String(_client.state.room.names[0]),
			_client.state.room.connected])
	else:
		_fail("the host's departure never reached this seat")
	if not await _until(func() -> bool: return not _client.online, 20000):
		_fail("the host service stopped but this client still believes it is online")
		return
	_say("service gone; client says: %s" % _client.status)
	await _until(func() -> bool: return _client.status.contains("Host unavailable"), 12000)
	_say("settled message: %s" % _client.status)
	_check(not _client.status.is_empty() and not _client.status.contains("invalid"),
		"the client's closing message is not a sane one: %s" % _client.status)


# ------------------------------------------------------ shared playing --

func _connect(invitation: String) -> bool:
	var started := Time.get_ticks_msec()
	var result := _client.connect_invitation(invitation, nickname)
	if not _check(result == OK, "connect_invitation failed with %d" % result):
		return false
	if not await _until(func() -> bool: return _client.online or not _client._wanted, 60000):
		_fail("never connected (status: %s)" % _client.status)
		return false
	if not _check(_client.online, "connection refused: %s" % _client.status):
		return false
	_say("connected in %dms as '%s' — %s" % [Time.get_ticks_msec() - started, _client.guest, _client.status])
	_check(_client.status.contains("encrypted LAN"),
		"this connection is not the encrypted LAN path: %s" % _client.status)
	return true


## Play [param seat] through the coverage pilot until the referee says the
## duel is over. Every decision is made from the received DTO alone.
func _play(seat: int) -> void:
	if not await _until(func() -> bool: return not _client.state.room.get("game", {}).is_empty(), 60000):
		_fail("the duel never started")
		return
	var opening := Time.get_ticks_msec()
	var view: Dictionary = _client.state.room.game
	_say("duel started: seat %d, toss won by seat %d, decks %s" % [seat,
		int(view.presentation.toss), _client.state.room.deck_names])
	var commands := 0
	var acted_revision := -1
	var mulliganed := false
	var dropped := drop_turn <= 0
	while commands < MAX_COMMANDS:
		if _failures > 0:
			return
		if String(_client.state.room.get("game", {}).get("mode", "")) == "finished":
			break
		if not _client.online or _client.busy() or int(_client.state.room.get("revision", 0)) <= acted_revision:
			await get_tree().process_frame
			continue
		view = _client.state.room.game
		if int(view.actor) != seat:
			await get_tree().process_frame
			continue
		if not dropped and int(view.turn) >= drop_turn:
			dropped = true
			await _drop_and_resume()
			acted_revision = -1
			continue
		acted_revision = int(_client.state.room.revision)
		var action: Dictionary = _pilot.choose(view, seat)
		# (c) One redraw, taken through the wire like any other decision,
		# so the opening is a real mulligan and not only a keep.
		if not mulliganed and String(view.mode) == "opening" and action.op == "keep":
			mulliganed = true
			action = {"op": "mulligan"}
			_say("taking one mulligan (hand was %d cards)" % view.hand.size())
		commands += 1
		if not await _act(action):
			return
	var final: Dictionary = _client.state.room.get("game", {})
	if not _check(String(final.get("mode", "")) == "finished",
		"the duel did not finish in %d commands" % MAX_COMMANDS):
		return
	# Every number here arrives as JSON, so it is printed as an integer
	# rather than as the float a parser hands back ("winner seat 0.0").
	_say("duel over after %dms and %d commands from this seat: turn %d, winner seat %d, draw %s, life %d vs %d, libraries %d vs %d" % [
		Time.get_ticks_msec() - opening, commands, int(final.turn), int(final.winner), bool(final.draw),
		int(final.players[0].life), int(final.players[1].life),
		int(final.players[0].library_count), int(final.players[1].library_count)])
	_check(int(final.winner) in [0, 1] or bool(final.draw), "the duel ended without a winner or a draw")


## (d) A mid-game disconnect and a resumption. The socket dies without a
## close frame — a pulled cable, not a polite departure — the seat stays
## held, and the duel on the other side must be the same duel afterwards.
func _drop_and_resume() -> void:
	var room: Dictionary = _client.state.room
	var before := {"room": String(room.id), "revision": int(room.revision), "turn": int(room.game.turn),
		"step": String(room.game.step), "life": [int(room.game.players[0].life), int(room.game.players[1].life)],
		"hand": room.game.hand.size(), "seat": int(room.seat)}
	_say("pulling the cable at turn %d (%s), room revision %d" % [before.turn, before.step, before.revision])
	# Stop polling first: an unpolled client cannot reconnect behind our
	# back, which is what makes this a real gap rather than a blink.
	_client.set_process(false)
	_client._socket.close(-1)
	_client._socket.poll()
	var down := Time.get_ticks_msec()
	await _until(func() -> bool: return false, drop_ms)
	_client.set_process(true)
	_client.reconnect()
	if not await _until(func() -> bool: return _client.online, 60000):
		_fail("never reconnected after %dms down (status: %s)" % [Time.get_ticks_msec() - down, _client.status])
		return
	var back := Time.get_ticks_msec()
	if not await _until(func() -> bool: return not _client.state.room.get("game", {}).is_empty(), 30000):
		_fail("reconnected but never received the room again")
		return
	var after: Dictionary = _client.state.room
	_say("back after %dms down (%dms of it reconnecting), room revision %d" % [
		back - down, back - (down + drop_ms), int(after.revision)])
	_check(String(after.id) == before.room, "reconnect landed in a different room")
	_check(int(after.seat) == before.seat, "reconnect landed in a different seat")
	_check(int(after.game.turn) == before.turn and String(after.game.step) == before.step,
		"the duel moved while this seat was away: turn %d/%s became %d/%s" % [
			before.turn, before.step, int(after.game.turn), String(after.game.step)])
	_check([int(after.game.players[0].life), int(after.game.players[1].life)] == before.life,
		"life totals changed across the gap: %s became %s" % [before.life,
			[int(after.game.players[0].life), int(after.game.players[1].life)]])
	_check(after.game.hand.size() == before.hand,
		"this seat's hand changed across the gap: %d became %d" % [before.hand, after.game.hand.size()])
	_say("resumed the same duel: turn %d %s, life %s, hand %d, revision %d -> %d" % [
		int(after.game.turn), String(after.game.step), before.life, before.hand,
		before.revision, int(after.revision)])


# --------------------------------------------------------------- numbers --

func _report() -> void:
	if not _round_trips.is_empty():
		var sorted := _round_trips.duplicate()
		sorted.sort()
		var total := 0
		for value: int in sorted:
			total += value
		_say("%d round trips: min %dms, median %dms, mean %.1fms, p95 %dms, max %dms" % [
			sorted.size(), sorted[0], sorted[sorted.size() / 2], float(total) / sorted.size(),
			sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], sorted[-1]])
	_say("largest command this seat sent: %d bytes (the limit is %d)" % [
		_largest_command, SgProtocol.MAX_COMMAND_BYTES])
	if _metered != null:
		for kind: String in _metered.largest:
			_say("largest '%s' the host sent: %d bytes (the view limit is %d)" % [kind,
				int(_metered.largest[kind]), SgProtocol.MAX_BYTES])
	_say("refusals: %d, failed checks: %d, wall clock %.1fs" % [_refusals.size(), _failures,
		(Time.get_ticks_msec() - _started) / 1000.0])
	print("LAN %s %s" % [role, "OK" if _failures == 0 else "NOT CLEAN"])
