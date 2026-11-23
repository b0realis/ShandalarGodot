class_name PackTransport
extends RefCounted
## ONE HTTPS REQUEST AT A TIME, for [PackFetch] — the game's own way to the
## card pictures, with nothing beside the engine ([HTTPClient]).
##
## The transport is a seam: [PackFetch] is handed one, and the tests hand
## it a fake that answers from a table, so no test opens a socket. This
## class is the real one. A caller starts a request ([method request]),
## calls [method poll] every frame until it says false, and reads [method
## result]: `{error, status, headers, body}`.
##
##   error    "" when an answer came (whatever its status), else
##            "bad_url"   not https, or not one of Scryfall's hosts
##            "connect"   no route, no name, a connection that dropped
##            "tls"       the secure handshake failed (certificates)
##            "timeout"   nothing whole within the time allowed
##            "too_big"   more than the caller's bound
##            "redirect"  redirected too often, or to another site
##            "off"       the network is switched off ([member network_allowed])
##   status   the HTTP status of the final answer
##   headers  lower-case name -> value
##   body     the bytes, never more than the bound
##
## WHAT IT WILL AND WILL NOT DO.
##   * https only, and only to `api.scryfall.com` and Scryfall's own file
##     hosts (`*.scryfall.io`, `*.scryfall.com`) — an address read out of an
##     answer is data, and data does not choose where the game connects.
##   * Certificates are checked with the engine's defaults; a failed check
##     is the error "tls", never a retry without it.
##   * One request in flight. A connection is kept open per host and used
##     again (two hosts: the API and the pictures), so a pack is not a
##     thousand handshakes. A server that says `Connection: close` is
##     taken at its word; a connection that drops, or on which nothing
##     moves for [constant STALL_MSEC], is opened afresh and the request
##     sent again — once; a second time is the error.
##   * Up to four redirects, each under the same host rule.
##   * The body is read a few chunks a poll, so a frame is never held.

const MAX_REDIRECTS := 4
const CONNECT_MSEC := 20000
## A request on which no byte has moved for this long is taken for dead
## (a kept connection the far end let go without a word).
const STALL_MSEC := 10000
## How long one [method poll] may read before it returns to the frame.
const POLL_USEC := 5000
const ALLOWED_HOSTS := ["api.scryfall.com"]
const ALLOWED_TAILS := [".scryfall.io", ".scryfall.com"]

## THE NETWORK CAN BE SWITCHED OFF, for every transport at once (the
## owner, 2026-11-23: "no downloads in tests, period"). While this is
## false no request resolves a name or opens a connection: each fails at
## once with the error "off" ([constant OFF_TEXT] in words) and is counted
## in [member refused_attempts], so a test can hold that nothing tried.
## The game itself never sets it; the test suite's pre-run hook does.
static var network_allowed := true
static var refused_attempts := 0
const OFF_TEXT := "The network is switched off here."

enum {IDLE, CONNECTING, REQUESTING, BODY}

var _clients := {}
var _client: HTTPClient = null
var _stage := IDLE
var _host := ""
var _path := ""
var _headers := PackedStringArray()
var _post := ""
var _max_bytes := 0
var _deadline := 0
var _connect_deadline := 0
var _redirects := 0
var _reused := false
var _retried := false
var _body := PackedByteArray()
var _result := {}
var _moved_at := 0
## For whoever measures a run: connections opened, and requests that had
## to be sent again on a fresh one.
var connects := 0
var resent := 0


## Start a GET of [param url] — or, with a [param body], a POST of it (a
## batched question; asking it twice changes nothing, so it too may be
## sent again on a fresh connection). The answer may hold [param max_bytes]
## at most and must be whole within [param timeout_msec].
func request(url: String, headers: PackedStringArray, max_bytes: int, timeout_msec: int,
		body := "") -> void:
	# Switched off: refused here, before a name is resolved. (An address
	# the game would not follow anyway is refused as that, below — it
	# never reaches the network either.)
	if not network_allowed and not parts_of(url).is_empty():
		_switched_off()
		return
	_headers = headers
	_post = body
	_max_bytes = max_bytes
	_deadline = Time.get_ticks_msec() + timeout_msec
	_redirects = 0
	_retried = false
	_result = {}
	_moved_at = Time.get_ticks_msec()
	_begin(url)


## True while the request is under way; false once [method result] holds
## its outcome (or nothing was asked).
func poll() -> bool:
	if _stage == IDLE:
		return false
	var now := Time.get_ticks_msec()
	if now > _deadline or (_stage == CONNECTING and now > _connect_deadline):
		_fail("timeout")
		return false
	if _stage != CONNECTING and now - _moved_at > STALL_MSEC:
		_dropped("timeout")
		return _stage != IDLE
	_client.poll()
	var status := _client.get_status()
	match _stage:
		CONNECTING:
			if status == HTTPClient.STATUS_CONNECTED:
				_send()
			elif status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				_fail("tls")
			elif status != HTTPClient.STATUS_RESOLVING and status != HTTPClient.STATUS_CONNECTING:
				_fail("connect")
		REQUESTING:
			if status == HTTPClient.STATUS_REQUESTING:
				pass
			elif status == HTTPClient.STATUS_BODY or (status == HTTPClient.STATUS_CONNECTED \
					and _client.has_response()):
				_answered()
			elif status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				_fail("tls")
			else:
				_dropped()
		BODY:
			_read_body()
	return _stage != IDLE


func result() -> Dictionary:
	return _result


## Drop the request in flight, if any; the kept connections stay.
func cancel() -> void:
	if _stage != IDLE:
		_forget_client()
	_stage = IDLE
	_result = {}


## Close every connection. The transport can be used again afterwards.
func close() -> void:
	for host: String in _clients:
		(_clients[host] as HTTPClient).close()
	_clients.clear()
	_client = null
	_stage = IDLE


## `[host, path]` of an address the game may ask, or an empty array.
static func parts_of(url: String) -> PackedStringArray:
	if not url.begins_with("https://"):
		return PackedStringArray()
	var rest := url.substr(8)
	var slash := rest.find("/")
	var host := (rest if slash < 0 else rest.left(slash)).to_lower()
	var path := "/" if slash < 0 else rest.substr(slash)
	# No port, no user, nothing but a plain name.
	if host == "" or host.contains("@") or host.contains(":") or host.contains("?") \
			or host.contains("#") or host.contains(" ") or path.contains(" ") \
			or path.contains("\n") or path.contains("\r"):
		return PackedStringArray()
	var allowed := ALLOWED_HOSTS.has(host)
	for tail: String in ALLOWED_TAILS:
		if host.ends_with(tail) and host.length() > tail.length():
			allowed = true
	if not allowed:
		return PackedStringArray()
	var hash_at := path.find("#")
	if hash_at >= 0:
		path = path.left(hash_at)
	return PackedStringArray([host, path])


func _begin(url: String) -> void:
	var parts := parts_of(url)
	if parts.is_empty():
		_stage = IDLE
		_result = {"error": "bad_url" if _redirects == 0 else "redirect", "status": 0,
			"headers": {}, "body": PackedByteArray()}
		return
	_host = parts[0]
	_path = parts[1]
	_body = PackedByteArray()
	_client = _clients.get(_host, null)
	if _client != null:
		_client.poll()
	if _client != null and _client.get_status() == HTTPClient.STATUS_CONNECTED:
		_reused = true
		_send()
		return
	_connect()


## Refused before anything is resolved or opened ([member network_allowed]).
func _switched_off() -> void:
	refused_attempts += 1
	_forget_client()
	_stage = IDLE
	_result = {"error": "off", "status": 0, "headers": {}, "body": PackedByteArray()}


func _connect() -> void:
	# Here too: the one place a connection is opened.
	if not network_allowed:
		_switched_off()
		return
	_forget_client()
	_reused = false
	_body = PackedByteArray()
	connects += 1
	_client = HTTPClient.new()
	_client.read_chunk_size = 65536
	_clients[_host] = _client
	var where := _endpoint(_host)
	if _client.connect_to_host(String(where[0]), int(where[1]), where[2] as TLSOptions) != OK:
		_fail("connect")
		return
	_connect_deadline = Time.get_ticks_msec() + CONNECT_MSEC
	_moved_at = Time.get_ticks_msec()
	_stage = CONNECTING


## Where [param host] is reached and how its certificate is checked:
## `[address, port, TLS options]` — the host itself, port 443, the engine's
## own certificate check. The game never changes this; it is a method so
## that a probe can point the transport at a server of its own.
func _endpoint(host: String) -> Array:
	return [host, 443, TLSOptions.client()]


func _send() -> void:
	_moved_at = Time.get_ticks_msec()
	var method := HTTPClient.METHOD_GET if _post == "" else HTTPClient.METHOD_POST
	if _client.request(method, _path, _headers, _post) != OK:
		_dropped()
		return
	_stage = REQUESTING


## The connection went, or went quiet, before the answer was whole: a
## fresh one and the same request again, once (a GET may be asked twice);
## the second time it is [param error].
func _dropped(error := "connect") -> void:
	if not _retried:
		_retried = true
		resent += 1
		_connect()
	else:
		_fail(error)


func _answered() -> void:
	var code := _client.get_response_code()
	var headers := _lower(_client.get_response_headers_as_dictionary())
	if code in [301, 302, 303, 307, 308] and headers.has("location"):
		# The body of a redirect is of no use: a fresh connection is
		# simpler than draining it.
		_forget_client()
		_redirects += 1
		if _redirects > MAX_REDIRECTS:
			_fail("redirect")
			return
		# A redirect is followed with a GET, as a browser follows one.
		if code != 307 and code != 308:
			_post = ""
		var target := String(headers["location"])
		if target.begins_with("/"):
			target = "https://" + _host + target
		_begin(target)
		return
	_moved_at = Time.get_ticks_msec()
	_result = {"error": "", "status": code, "headers": headers, "body": PackedByteArray()}
	var length := int(String(headers.get("content-length", "-1")))
	if length > _max_bytes:
		_fail("too_big")
		return
	_stage = BODY
	_read_body()


func _read_body() -> void:
	var started := Time.get_ticks_usec()
	while true:
		_client.poll()
		var status := _client.get_status()
		if status == HTTPClient.STATUS_BODY:
			var chunk := _client.read_response_body_chunk()
			if not chunk.is_empty():
				_moved_at = Time.get_ticks_msec()
				_body.append_array(chunk)
				if _body.size() > _max_bytes:
					_fail("too_big")
					return
			if Time.get_ticks_usec() - started > POLL_USEC:
				return
			if chunk.is_empty():
				return
			continue
		if status != HTTPClient.STATUS_CONNECTED:
			# Cut short. A declared length that was not met is a failure;
			# without one the caller judges what arrived.
			var declared := int(String((_result["headers"] as Dictionary).get("content-length", "-1")))
			if declared >= 0 and declared != _body.size():
				_dropped()
				return
			_forget_client()
		_finish()
		return


func _finish() -> void:
	var headers: Dictionary = _result["headers"]
	if String(headers.get("content-encoding", "")).to_lower() == "gzip" and not _body.is_empty():
		_body = _body.decompress_dynamic(_max_bytes, FileAccess.COMPRESSION_GZIP)
	_result["body"] = _body
	_body = PackedByteArray()
	# Told the connection ends here: the next request opens its own.
	if String(headers.get("connection", "")).to_lower().contains("close"):
		_forget_client()
	_stage = IDLE


func _fail(error: String) -> void:
	_forget_client()
	_body = PackedByteArray()
	_result = {"error": error, "status": 0, "headers": {}, "body": PackedByteArray()}
	_stage = IDLE


func _forget_client() -> void:
	if _client != null:
		_client.close()
	if _clients.get(_host, null) == _client:
		_clients.erase(_host)
	_client = null


static func _lower(headers: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in headers:
		out[String(key).to_lower()] = String(headers[key])
	return out
