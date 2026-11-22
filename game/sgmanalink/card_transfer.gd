class_name SgCardTransfer
extends Node
## [QoL] THE HOST'S COMMUNITY CARDS, FETCHED FROM THE LOBBY (2026-11-17).
## Both players at a LAN table need the same community cards ([method
## SgCompatibility.community_mark]); a guest whose cards differ is refused
## at the hello, and the lobby offers to get the host's. This node opens its
## own connection to the host — no hello, the access code in every request
## — and asks for the host's list: each card's name, its playing digest
## ([method SgCompatibility.card_digest]) and the most its zip may be, and
## the host's mark. [method plan] works out what to add, replace and set
## aside; the lobby asks the player first ([method plan_text]); then each
## needed zip comes in chunks ([method download]).
##
## THE ZIPS WAIT IN MEMORY. The card catalogue is locked while any
## SGManalink connection is open ([method CardPacks.change_refusal]), so
## [method apply] runs once every connection has closed: it checks every
## zip, sets the player's replaced and extra cards aside — moved (a
## replaced card copied, then saved over), never deleted, into
## [constant SET_ASIDE] of the own folder, which the scan never reads —
## installs the host's ([method CommunityCards.install]) and rebuilds the
## pool. A problem stops the batch and puts everything back; a record in
## the set-aside folder lets the lobby put it back after a crash too
## ([method restore_batch]).
##
## The host sends only the zips of its own playable cards, found by name in
## its own list ([method shelf]); no path or file name from the wire ever
## names a file on either computer.

signal listed(plan: Dictionary)
signal downloaded(zips: Dictionary)
signal failed(reason: String)
signal progressed(words: String)

## What one chunk carries (the host's; tests may lower [member chunk_bytes]),
## and the most a reply may carry: its base64 stays within
## [constant SgProtocol.MAX_BYTES]. A chunk under [constant MIN_CHUNK] that
## is not a zip's last is refused: a host that dribbles is let go.
const CHUNK := 524288
const MAX_CHUNK := 1048576
const MIN_CHUNK := 65536
static var chunk_bytes := CHUNK
## The most cards a host lists.
const MAX_LIST := SgProtocol.MAX_CARDS
## The most cards and bytes one transfer fetches: the rest wait for the next.
const MAX_CARDS := 200
const MAX_TOTAL := 96 * 1024 * 1024
## The most chunk requests one connection may make (the host's count): what
## the largest transfer needs — every byte in whole chunks and each card's
## last, shorter one — and one zip more.
const MAX_REQUESTS := MAX_CARDS + (MAX_TOTAL + CommunityCards.MAX_ZIP) / CHUNK
## The largest size a list may name (a zip past [constant
## CommunityCards.MAX_ZIP] is listed, never sent).
const MAX_LISTED := 1073741824
## The most a card zip's files may unpack to: its art (4 MB), its icon
## (64 KB) and its card.json fit well within it.
const MAX_UNPACKED := CommunityCards.MAX_ZIP
const MAX_NAME := 64
## The most lists one connection may ask for (the host's count).
const MAX_LISTS := 4
## The own folder's subfolder the replaced and extra cards are moved to,
## and the record of a batch under way in it.
const SET_ASIDE := "set_aside"
const BATCH := ".batch.json"
const BATCH_FORMAT := "shandalar-card-transfer-batch"
## The own folder's side folder a downloaded zip is checked in.
const CHECK_FOLDER := ".transfer"
const CONNECT_MS := 5000
const REPLY_MS := 15000
## The whole download's time: this, and a second for each
## [constant MIN_RATE] bytes.
const GRACE_MS := 30000
const MIN_RATE := 262144
## Between two requests: below the host's flood limit (64 a second).
const PACE_MS := 40
const INVALID := "The host sent an invalid answer about its community cards. Try again."
const TOO_MANY := "This connection has asked for the host's cards too often. Try again."
const SLOW := "The host sends its cards too slowly. Try again when the network is quieter."

## The connection: `{address, port, access, tls}` ([method valid_target]).
var target: Dictionary = {}
## "" (idle), "list" or "download".
var phase := ""
var _socket: WebSocketPeer
var _closing: Array = []
var _opened := 0
var _waiting := false
var _deadline := 0
var _give_up_at := 0
var _due := 0
var _plan: Dictionary = {}
var _queue: Array = []
## The card coming in (`[name, digest, listed size]`), its bytes so far
## and its exact size once the host has said it (-1 before).
var _current: Array = []
var _bytes := PackedByteArray()
var _total := -1
var _zips: Dictionary = {}
var _fetched := 0


# ------------------------------------------------------------- the host --

## The host's cards it may send, in the order of their names: `{name, spec,
## digest, size, file}`. `file` is the host's own zip of a single card, ""
## for a card of a set zip (packed alone when it is sent, [method
## bytes_of]); `size` the zip's exact size, or for a set's card the most
## its packed zip can be ([method _bound_of]) — measured without packing.
## Past [constant MAX_LIST] cards nothing is measured: the list is refused.
## [param rows] (`{name, path, spec}`) stand in for the scan: a test's host,
## whose cards are the zips at their paths.
static func shelf(rows: Array = []) -> Array:
	var out: Array = []
	if rows.is_empty():
		var found: Array = []
		for row in CommunityCards.playable():
			if CardRegistry.has_community(String(row["name"])) and card_name(row["name"]):
				found.append(row)
		var measure := found.size() <= MAX_LIST
		for row: Dictionary in found:
			var card_id := String(row["name"])
			var spec: Variant = row["spec"]
			# Every card is sent packed afresh from its files, as Export
			# writes it — never the host's own zip, which may carry what a
			# guest refuses (a Mac's litter, a second art).
			var size := 0
			if measure:
				size = _bound_of(card_id, spec if spec is Dictionary else {})
			out.append(_shelf_row(card_id, spec, size, ""))
	else:
		for row in rows:
			if row is Dictionary and card_name(row.get("name")):
				var path := String(row.get("path", ""))
				out.append(_shelf_row(String(row["name"]), row.get("spec", {}), _size_of(path), path))
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return String(x["name"]) < String(y["name"]))
	return out


static func _shelf_row(card: String, spec: Variant, size: int, file: String) -> Dictionary:
	var clean: Dictionary = spec if spec is Dictionary else {}
	return {"name": card, "spec": clean, "digest": SgCompatibility.card_digest(clean),
		"size": clampi(size, 0, MAX_LISTED), "file": file}


static func _size_of(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ) if path != "" else null
	return int(file.get_length()) if file != null else 0


## The most a set's card zip can be once packed alone, from its files'
## own sizes: each file deflated at worst, with its headers in the zip and
## in the zip's list ([method CommunityCards.write_zip] writes card.json,
## the icon and the art under the card's top folder).
static func _bound_of(card: String, spec: Dictionary) -> int:
	var files := CommunityCards.files_of(card)
	var sizes: Array[int] = [JSON.stringify(spec, "\t", false).to_utf8_buffer().size()]
	var pictures: Array = CommunityCards.icon_pictures(files.get("icon", {}))
	if not (files.get("art", {}) as Dictionary).is_empty():
		pictures.append(files["art"])
	for picture: Dictionary in pictures:
		var bytes: PackedByteArray = picture["bytes"]
		sizes.append(bytes.size())
	var top := CommunityCards.file_name(String(spec.get("name", card))).length()
	var bound := 22 + 1024
	for n in sizes:
		bound += n + (n >> 12) + (n >> 14) + 13 + 2 * (top + 16) + 30 + 46 + 16 + 128
	return bound


## The host's row named [param card] exactly ({} when none): the only way a
## name from the wire reaches a card.
static func shelf_row(cards: Array, card: String) -> Dictionary:
	for row: Dictionary in cards:
		if String(row["name"]) == card:
			return row
	return {}


## Whether the host may send [param row]'s zip at all.
static func sendable(row: Dictionary) -> bool:
	return not row.is_empty() and int(row["size"]) >= 1 and int(row["size"]) <= CommunityCards.MAX_ZIP


## The bytes the guest gets for [param row] ([method sendable] first): the
## card's zip as it would be shared, packed alone when it is a set's.
static func bytes_of(row: Dictionary) -> PackedByteArray:
	if not sendable(row):
		return PackedByteArray()
	var file := String(row["file"])
	if file != "":
		return FileAccess.get_file_as_bytes(file) if _size_of(file) <= CommunityCards.MAX_ZIP else PackedByteArray()
	return CommunityCards.zip_bytes_of(String(row["name"]))


## The list a guest reads: `[name, digest, size]` rows and the host's mark.
static func list_reply(cards: Array) -> Dictionary:
	var reply := {"type": "cards", "mark": "", "cards": [], "error": ""}
	if cards.size() > MAX_LIST:
		reply["error"] = "The host has more than %d community cards: copy them by hand." % MAX_LIST
		return reply
	var specs: Array = []
	var rows: Array = []
	for row: Dictionary in cards:
		rows.append([row["name"], row["digest"], row["size"]])
		specs.append(row["spec"])
	reply["cards"] = rows
	reply["mark"] = SgCompatibility.mark_of(specs)
	return reply


## One chunk of [param card]'s zip from [param offset]: [param row] is the
## host's own row of that name ([method shelf_row]), [param bytes] its zip
## ([method bytes_of]) — the same bytes for every chunk of one transfer.
## `total` is the zip's exact size, at most the size the list named.
static func chunk_reply(row: Dictionary, card: String, offset: int, bytes: PackedByteArray) -> Dictionary:
	var reply := {"type": "card", "name": card, "offset": offset, "total": 0, "data": "", "error": ""}
	if row.is_empty():
		reply["error"] = "The host has no community card named %s." % card
		return reply
	if not sendable(row):
		reply["error"] = "%s is too large to send: a card zip is at most %s." % [card,
			PortableMode.size_words(CommunityCards.MAX_ZIP)]
		return reply
	if bytes.is_empty() or bytes.size() > int(row["size"]):
		reply["error"] = "%s changed on the host since it was read. The host can host again to read it anew." % card
		return reply
	if offset >= bytes.size():
		reply["error"] = "The host's %s has no bytes at %d." % [card, offset]
		return reply
	reply["total"] = bytes.size()
	reply["data"] = Marshalls.raw_to_base64(bytes.slice(offset,
		offset + mini(clampi(chunk_bytes, 1, MAX_CHUNK), bytes.size() - offset)))
	return reply


# ------------------------------------------------------ the wire checks --

## A card's name on the wire: plain text, at most [constant MAX_NAME].
static func card_name(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_NAME \
		and value == value.strip_edges() and SgViewProtocol.text(value, MAX_NAME)


static func valid_list(message: Dictionary) -> bool:
	if not SgProtocol.exact(message, ["type", "mark", "cards", "error"]) or not SgProtocol.literal(message.type, "cards") \
		or not SgViewProtocol.text(message.error, 512) or not message.cards is Array or message.cards.size() > MAX_LIST \
		or not message.mark is String or (message.mark != "" and not SgCompatibility.plain(message.mark, 24)):
		return false
	# One card a name, in any case: the host's own scan never keeps two.
	var seen := {}
	for row in message.cards:
		if not row is Array or row.size() != 3 or not card_name(row[0]) or not SgProtocol.token(row[1]) \
			or not SgProtocol.integer(row[2], 0, MAX_LISTED):
			return false
		var lower := String(row[0]).to_lower()
		if seen.has(lower):
			return false
		seen[lower] = true
	return true


static func valid_chunk(message: Dictionary) -> bool:
	return SgProtocol.exact(message, ["type", "name", "offset", "total", "data", "error"]) \
		and SgProtocol.literal(message.type, "card") and card_name(message.name) \
		and SgProtocol.integer(message.offset, 0, CommunityCards.MAX_ZIP) \
		and SgProtocol.integer(message.total, 0, CommunityCards.MAX_ZIP) \
		and message.data is String and message.data.length() <= 4 * ((MAX_CHUNK + 2) / 3) \
		and SgViewProtocol.text(message.error, 512)


static func valid_target(where: Dictionary) -> bool:
	var tls: Variant = where.get("tls")
	return SgProtocol.exact(where, ["address", "port", "access", "tls"]) and SgLanInvite.address(where.address) \
		and SgProtocol.integer(where.port, 1, 65535) and SgProtocol.token(where.access) \
		and (tls == null or tls is TLSOptions)


## Where a LAN invitation connects: `{address, port, access, tls}`, {} when
## it is no invitation of this version.
static func target_of_invitation(invitation: String) -> Dictionary:
	var data := SgLanInvite.parse(invitation.strip_edges())
	var cert := SgLanInvite.certificate(data) if not data.is_empty() else null
	if cert == null:
		return {}
	return {"address": String(data.address), "port": int(data.port), "access": String(data.access),
		"tls": TLSOptions.client(cert, SgLanInvite.COMMON_NAME)}


# ------------------------------------------------------------- the plan --

## This game's community cards: name → `{digest, where, own, stays}`.
## `where` is the copy that plays — "own" (a zip of its own in the own
## folder), "set" (a card of a set zip) or "beside" (found beside the
## game); `own` every own single zip of the card, the one that plays and any
## the scan refused as found later, in any case; `stays` "" when that is
## every copy, else where another copy is ("beside" or "set") — a copy that
## would play once the others went.
static func mine() -> Dictionary:
	var own_root := ProjectSettings.globalize_path(CommunityCards.own_folder())
	var copies := {}
	var playing := {}
	for row in CommunityCards.all():
		if not _a_copy(row):
			continue
		var lower := String(row["name"]).to_lower()
		var path := ProjectSettings.globalize_path(String(row["path"]))
		var where := "set" if bool(row.get("set", false)) else ("own" if path.get_base_dir() == own_root else "beside")
		if (row["problems"] as Array).is_empty():
			playing[lower] = where
		if not copies.has(lower):
			copies[lower] = []
		(copies[lower] as Array).append({"where": where, "path": path})
	var out := {}
	for card_id in CardRegistry.community_names():
		var lower := card_id.to_lower()
		var own: Array = []
		var stays := ""
		for copy: Dictionary in copies.get(lower, []):
			if String(copy["where"]) == "own":
				if not own.has(copy["path"]):
					own.append(String(copy["path"]))
			elif stays != "beside":
				stays = String(copy["where"])
		out[card_id] = {"digest": SgCompatibility.card_digest(CommunityCards.spec_of(card_id)),
			"where": String(playing.get(lower, "beside")), "own": own, "stays": stays}
	return out


## Whether a scanned row is a copy of a card: one that plays, or one the
## scan refused only because another copy of its name was found first.
static func _a_copy(row: Dictionary) -> bool:
	var spec: Variant = row.get("spec", {})
	if not spec is Dictionary or (spec as Dictionary).is_empty():
		return false
	var problems: Array = row.get("problems", [])
	return problems.is_empty() or bool(row.get("shadowed", false))


## Where a card that cannot be taken away is reported ("" when every copy
## of it is an own zip, which can be set aside).
static func _left_of(yours: Dictionary) -> String:
	var where := String(yours["where"])
	var stays := String(yours["stays"])
	if where == "beside" or stays == "beside":
		return "stuck"
	if where == "set" or stays == "set":
		return "in_set"
	return ""


## What getting the host's [param cards] (`[name, digest, size]` rows) does
## to [param have] ([method mine]): `want` — the rows to fetch, at most
## [constant MAX_CARDS] and [constant MAX_TOTAL] bytes — split into `add`
## and `replace` (the own zip that plays is set aside and the host's takes
## its place; `shadowed` names those whose other copies stay behind it);
## `set_aside`, the own cards the host has none of, every own copy. Left as
## they are, and still different: `stuck`, a copy beside the game;
## `in_set`, a copy in a set zip (its file holds other cards too);
## `too_large`, the host's that cannot be sent; `later`, past this
## transfer's limits. And `same`, and the host's `mark` to match.
static func plan(cards: Array, host_mark: String, have: Dictionary) -> Dictionary:
	var out := {"mark": host_mark, "want": [], "bytes": 0, "add": [], "replace": [], "shadowed": [],
		"set_aside": [], "stuck": [], "in_set": [], "too_large": [], "later": [], "same": 0, "host": cards.size()}
	var rows := cards.duplicate()
	rows.sort_custom(func(x: Array, y: Array) -> bool: return String(x[0]) < String(y[0]))
	var lower_mine := {}
	for card_id in have:
		lower_mine[String(card_id).to_lower()] = String(card_id)
	var listed := {}
	var listed_lower := {}
	var coming := {}
	for row: Array in rows:
		var card_id := String(row[0])
		listed[card_id] = true
		listed_lower[card_id.to_lower()] = true
		var kind := "add"
		var yours_id := String(lower_mine.get(card_id.to_lower(), ""))
		if yours_id == card_id:
			var yours: Dictionary = have[card_id]
			if String(yours["digest"]) == String(row[1]):
				out["same"] = int(out["same"]) + 1
				continue
			if String(yours["where"]) != "own":
				(out[_left_of(yours)] as Array).append(card_id)
				continue
			kind = "replace"
		elif yours_id != "":
			# Yours spelled otherwise ("ELF LORD") goes only if every copy can.
			var left := _left_of(have[yours_id])
			if left != "":
				(out[left] as Array).append(card_id)
				continue
		var size := int(row[2])
		if size < 1 or size > CommunityCards.MAX_ZIP:
			(out["too_large"] as Array).append(card_id)
			continue
		if (out["want"] as Array).size() >= MAX_CARDS or int(out["bytes"]) + size > MAX_TOTAL:
			(out["later"] as Array).append(card_id)
			continue
		(out["want"] as Array).append([card_id, String(row[1]), size])
		coming[card_id.to_lower()] = true
		out["bytes"] = int(out["bytes"]) + size
		(out[kind] as Array).append(card_id)
		if kind == "replace" and String((have[card_id] as Dictionary)["stays"]) != "":
			(out["shadowed"] as Array).append(card_id)
	var names := have.keys()
	names.sort()
	for card_id in names:
		# Yours spelled otherwise than the host's stays unless the host's
		# comes now (too large, or left for later, it would leave neither).
		var lower := String(card_id).to_lower()
		if not listed.has(card_id) and not (listed_lower.has(lower) and not coming.has(lower)):
			var left := _left_of(have[card_id])
			(out[left if left != "" else "set_aside"] as Array).append(String(card_id))
	return out


## Whether [param p] changes anything here.
static func has_work(p: Dictionary) -> bool:
	return not (p.get("want", []) as Array).is_empty() or not (p.get("set_aside", []) as Array).is_empty()


## Its first line: "Add N cards, replace M, set aside K of yours."
static func headline(p: Dictionary) -> String:
	var n := (p["add"] as Array).size()
	return "Add %d card%s, replace %d, set aside %d of yours." % [n, "" if n == 1 else "s",
		(p["replace"] as Array).size(), (p["set_aside"] as Array).size()]


## What the lobby says before it does anything: exactly what will happen.
static func plan_text(p: Dictionary) -> String:
	var lines: Array[String] = []
	if not has_work(p):
		lines.append("Nothing here can be changed to match the host's community cards.")
	else:
		lines.append(headline(p))
	if not (p["add"] as Array).is_empty():
		lines.append("Add, new to you: %s." % _names(p["add"]))
	if not (p["replace"] as Array).is_empty():
		lines.append("Replace, as yours plays differently: %s." % _names(p["replace"]))
	if not (p["shadowed"] as Array).is_empty():
		lines.append("Other copies of %s beside the game or in a set zip stay where they are, unused." \
			% _names(p["shadowed"]))
	if not (p["set_aside"] as Array).is_empty():
		lines.append("Set aside, as the host has none: %s." % _names(p["set_aside"]))
	if not (p["replace"] as Array).is_empty() or not (p["set_aside"] as Array).is_empty():
		lines.append("Your replaced and set-aside cards are moved to %s, never deleted: move a zip back to use the card again." \
			% GamePaths.shown(aside_folder()))
	if not (p["stuck"] as Array).is_empty():
		lines.append("Found beside the game, outside your data folder, so they can't be set aside: %s. They still differ; move them by hand." \
			% _names(p["stuck"]))
	if not (p["in_set"] as Array).is_empty():
		lines.append("Yours are part of a set zip, so they can't be set aside one by one: %s. They still differ." \
			% _names(p["in_set"]))
	if not (p["too_large"] as Array).is_empty():
		lines.append("The host can't send these (a card zip is at most %s): %s." % [
			PortableMode.size_words(CommunityCards.MAX_ZIP), _names(p["too_large"])])
	if not (p["later"] as Array).is_empty():
		var n := (p["later"] as Array).size()
		lines.append("%d more card%s wait for the next transfer (at most %d cards and %s at a time): get the host's cards again afterwards." \
			% [n, "" if n == 1 else "s", MAX_CARDS, PortableMode.size_words(MAX_TOTAL)])
	if has_work(p):
		var download := "" if (p["want"] as Array).is_empty() \
			else "The download is at most %s. " % PortableMode.size_words(int(p["bytes"]))
		lines.append(download + "You leave the host while the cards are installed, then join it again.")
	return "\n".join(lines)


## A few names, then how many more.
static func _names(names: Array, shown := 12) -> String:
	var head: PackedStringArray = []
	for card_id in names.slice(0, shown):
		head.append(String(card_id))
	var text := ", ".join(head)
	if names.size() > shown:
		text += " and %d more" % (names.size() - shown)
	return text


static func aside_folder() -> String:
	return ProjectSettings.globalize_path(CommunityCards.own_folder()).path_join(SET_ASIDE)


# ------------------------------------------------------------ the apply --

## Install the host's cards ([param zips]: name → bytes, as downloaded for
## [param p]) once no SGManalink connection is open. Returns `{problem,
## message, matched, mark}`: `problem` "" when installed, `matched` when this
## game's community mark is now the host's. Every zip is checked first,
## nothing moved yet. Then, a record of the batch written, every own copy of
## each extra card is moved aside and each replaced card's own zip copied
## aside; then each zip is installed — a replaced card's over its own zip,
## so any other copy stays behind it. A problem on the way takes this
## batch's installs out, puts every card back and rebuilds the pool.
static func apply(p: Dictionary, zips: Dictionary) -> Dictionary:
	var out := {"problem": "", "message": "", "matched": false, "mark": ""}
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		out["problem"] = refusal
		return out
	for row: Array in p["want"]:
		var why := _check(String(row[0]), String(row[1]), int(row[2]), zips.get(row[0], PackedByteArray()))
		if why != "":
			out["problem"] = why + " Nothing was changed."
			return out
	# Every move decided before any is made: [from, to, "move" | "copy"].
	var have := mine()
	var moves: Array = []
	var taken := {}
	for card_id in p["set_aside"]:
		var yours: Dictionary = have.get(card_id, {})
		if yours.is_empty() or _left_of(yours) != "" or (yours["own"] as Array).is_empty():
			out["problem"] = "%s changed since the host's cards were listed. Nothing was changed." % card_id
			return out
		for path in yours["own"]:
			moves.append([String(path), _aside_path(String(path).get_file(), taken), "move"])
	for card_id in p["replace"]:
		var playing := CommunityCards.own_path_of(String(card_id))
		if playing == "":
			out["problem"] = "%s changed since the host's cards were listed. Nothing was changed." % card_id
			return out
		moves.append([ProjectSettings.globalize_path(playing), _aside_path(playing.get_file(), taken), "copy"])
	for move: Array in moves:
		if String(move[1]) == "":
			out["problem"] = "%s could not be written. Nothing was changed." % GamePaths.shown(aside_folder())
			return out
	if not moves.is_empty() and not _write_batch(moves, []):
		out["problem"] = "%s could not be written. Nothing was changed." % GamePaths.shown(batch_path())
		return out
	var done: Array = []
	for move: Array in moves:
		var made := DirAccess.rename_absolute(move[0], move[1]) if move[2] == "move" \
			else DirAccess.copy_absolute(move[0], move[1])
		if made != OK:
			out["problem"] = "%s could not be set aside.%s" % [String(move[0]).get_file(), _undo(done, [])]
			return out
		done.append(move)
	# The set-aside cards are gone from the folder: installs see that.
	CommunityCards.scan()
	var installed: Array = []
	for row: Array in p["want"]:
		var zip: PackedByteArray = zips[row[0]]
		var result := CommunityCards.install(zip, (p["replace"] as Array).has(row[0]))
		if String(result["problem"]) != "":
			out["problem"] = "%s could not be installed: %s%s" % [row[0], result["problem"], _undo(done, installed)]
			return out
		var put := ProjectSettings.globalize_path(String(result["path"]))
		installed.append([put, _stamp(put)])
		if not moves.is_empty():
			_write_batch(moves, installed)
	_forget_batch()
	CommunityCards.refresh()
	out["mark"] = SgCompatibility.community_mark()
	out["matched"] = String(out["mark"]) == String(p["mark"])
	out["message"] = _result_text(p, bool(out["matched"]))
	return out


## Why [param bytes] are not the host's card [param card] as listed ("").
## A card zip holds one top folder with the card's own files only — its
## card.json, its icon and at most one art — that unpack to at most
## [constant MAX_UNPACKED]: never a set, a sub-folder or anything else.
## Checked from the zip's own list before a byte is unpacked.
static func _check(card: String, digest: String, size: int, bytes: Variant) -> String:
	if not bytes is PackedByteArray:
		return "%s was not downloaded." % card
	var zip: PackedByteArray = bytes
	if zip.is_empty():
		return "%s was not downloaded." % card
	if size > CommunityCards.MAX_ZIP or zip.size() > size:
		return "The host's %s is not the size it listed." % card
	if CardRegistry.game_name_like(card) != "":
		return "A card named %s is already in the game." % card
	var folder := CommunityCards.ensure_own_folder().path_join(CHECK_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("card.zip")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "%s could not be written." % GamePaths.shown(folder)
	file.store_buffer(zip)
	file.close()
	var why := _plain_card_zip(path)
	var row := CommunityCards.read(path) if why == "" else {}
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	if why != "":
		return "The host's %s is not a plain card zip: %s." % [card, why]
	var problems: Array = row["problems"]
	if not problems.is_empty():
		return "The host's %s was refused: %s" % [card, problems[0]]
	if String(row["name"]) != card:
		return "The host's zip for %s holds another card (%s)." % [card, row["name"]]
	if SgCompatibility.card_digest(row["spec"]) != digest:
		return "The host's %s is not the card it listed." % card
	return ""


## Why the zip at [param path] is not one card's own files ("" when it is).
static func _plain_card_zip(path: String) -> String:
	var listed := PluginPackage.zip_entries(path)
	if String(listed["problem"]) != "":
		return String(listed["problem"])
	var top := ""
	var files := {}
	var unpacked := 0
	for entry: Dictionary in listed["entries"]:
		var entry_name := String(entry["name"])
		if bool(entry.get("link", false)):
			return "it holds a link (%s)" % entry_name.left(60)
		var parts := entry_name.split("/")
		var folder_entry := entry_name.ends_with("/") and parts.size() == 2
		if not folder_entry and (parts.size() != 2 or parts[0] == "" or parts[1] == ""):
			return "it holds %s, more than one card's own files" % entry_name.left(60)
		if top == "":
			top = parts[0]
		elif parts[0] != top:
			return "it holds more than one top folder"
		if folder_entry:
			continue
		var file := parts[1]
		if not CommunityCards.ART_NAMES.has(file) and not CommunityCards.is_icon_file(file) \
				and file != CommunityCards.MANIFEST:
			return "it holds %s besides the card's own files" % file.left(60)
		if files.has(file):
			return "it holds %s twice" % file
		files[file] = true
		unpacked += maxi(0, int(entry["size"]))
	var arts := 0
	var icons := 0
	for each in files:
		if CommunityCards.ART_NAMES.has(String(each)):
			arts += 1
		elif CommunityCards.is_icon_file(String(each)):
			icons += 1
	if not files.has(CommunityCards.MANIFEST) or arts > 1 or icons < 1:
		return "a card zip holds its card.json, its set icons and at most one art"
	if unpacked > MAX_UNPACKED:
		return "it unpacks to %s; a card zip's files are at most %s" % [PortableMode.size_words(unpacked),
			PortableMode.size_words(MAX_UNPACKED)]
	return ""


## A free place in the set-aside folder for the own zip [param file], none
## of the places already [param taken] by this batch.
static func _aside_path(file: String, taken: Dictionary) -> String:
	var folder := aside_folder()
	if DirAccess.make_dir_recursive_absolute(folder) != OK and not DirAccess.dir_exists_absolute(folder):
		return ""
	var path := folder.path_join(file)
	var n := 2
	while FileAccess.file_exists(path) or taken.has(path):
		path = folder.path_join("%s_%d.%s" % [file.get_basename(), n, file.get_extension()])
		n += 1
	taken[path] = true
	return path


## Undo a batch: take its [param installed] zips out (a replaced card's is
## put back below) and put every [param done] move back (`[from, to,
## kind]`, the last first), then forget the record and rebuild the pool.
## Says what is left behind, by name, when anything is.
static func _undo(done: Array, installed: Array) -> String:
	var left: Array[String] = []
	var copied := {}
	for move: Array in done:
		if move[2] == "copy":
			copied[String(move[0])] = true
	# An installed zip changed since (a card saved over it after a cut-short
	# batch) is the player's work now: set aside, never deleted.
	var stamps := {}
	for entry: Array in installed:
		stamps[String(entry[0])] = String(entry[1])
	var own := GamePaths.shown(ProjectSettings.globalize_path(CommunityCards.own_folder()))
	var aside := GamePaths.shown(aside_folder())
	var taken := {}
	for i in range(installed.size() - 1, -1, -1):
		var path := String(installed[i][0])
		if copied.has(path) or not FileAccess.file_exists(path):
			continue
		if _stamp(path) != String(stamps[path]):
			var kept := _aside_path(path.get_file(), taken)
			if kept == "" or DirAccess.rename_absolute(path, kept) != OK:
				left.append("the host's %s in %s" % [path.get_file(), own])
			else:
				left.append("a card saved since, %s in %s" % [kept.get_file(), aside])
			continue
		if DirAccess.remove_absolute(path) != OK:
			left.append("the host's %s in %s" % [path.get_file(), own])
	for i in range(done.size() - 1, -1, -1):
		var move: Array = done[i]
		var from := String(move[0])
		var to := String(move[1])
		if not FileAccess.file_exists(to):
			continue
		if move[2] == "copy" and FileAccess.file_exists(from):
			var gone := false
			if stamps.has(from) and _stamp(from) != String(stamps[from]):
				var kept := _aside_path(from.get_file(), taken)
				gone = kept != "" and DirAccess.rename_absolute(from, kept) == OK
				if gone:
					left.append("a card saved since, %s in %s" % [kept.get_file(), aside])
			else:
				gone = DirAccess.remove_absolute(from) == OK
			if not gone:
				left.append("yours, %s in %s" % [to.get_file(), aside])
				continue
		if FileAccess.file_exists(from) or DirAccess.rename_absolute(to, from) != OK:
			left.append("yours, %s in %s" % [to.get_file(), aside])
	_forget_batch()
	CommunityCards.refresh()
	if left.is_empty():
		return " Your cards are as they were."
	return " Left behind: %s." % _names(left)


## What came of it. Cards that still differ are said first, in the
## difference's own words (the lobby says those in red).
static func _result_text(p: Dictionary, matched: bool) -> String:
	var text := "Got the host's community cards: added %d, replaced %d, set aside %d." % [
		(p["add"] as Array).size(), (p["replace"] as Array).size(), (p["set_aside"] as Array).size()]
	if not (p["replace"] as Array).is_empty() or not (p["set_aside"] as Array).is_empty():
		text += " Yours are in %s." % GamePaths.shown(aside_folder())
	if matched:
		return text + " Your community cards now match the host's."
	var why: Array[String] = []
	if not (p["stuck"] as Array).is_empty():
		why.append("found beside the game: " + _names(p["stuck"]))
	if not (p["in_set"] as Array).is_empty():
		why.append("yours in a set zip: " + _names(p["in_set"]))
	if not (p["too_large"] as Array).is_empty():
		why.append("the host can't send " + _names(p["too_large"]))
	if not (p["later"] as Array).is_empty():
		why.append("%d left for the next transfer" % (p["later"] as Array).size())
	if why.is_empty():
		why.append("the cards changed meanwhile")
	return "%s still (%s). %s" % [SgCompatibility.COMMUNITY_WORDS, "; ".join(why), text]


# -------------------------------------------------- the batch's record --

## THE RECORD OF A BATCH UNDER WAY (2026-11-17): its moves and the installs
## made so far, in the set-aside folder, written before anything moves and
## gone when the batch is done or undone. One left behind is a batch a
## crash cut short: the lobby offers to put it back ([method restore_batch]).
## What tells a file apart from when it was installed: size and time.
static func _stamp(path: String) -> String:
	return "%d|%d" % [_size_of(path), FileAccess.get_modified_time(path)]


static func batch_path() -> String:
	return aside_folder().path_join(BATCH)


static func left_batch() -> bool:
	return FileAccess.file_exists(batch_path())


static func _write_batch(moves: Array, installed: Array) -> bool:
	DirAccess.make_dir_recursive_absolute(aside_folder())
	var file := FileAccess.open(batch_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"format": BATCH_FORMAT, "moves": moves, "installed": installed}, "\t"))
	file.close()
	return true


static func _forget_batch() -> void:
	if left_batch():
		DirAccess.remove_absolute(batch_path())


## Forget a cut-short batch, its cards left where they are.
static func dismiss_batch() -> void:
	_forget_batch()


## Put a cut-short batch back as it was before ([method _undo]): what to
## say. Only places in the own folder and its set-aside folder are touched,
## whatever the record says.
static func restore_batch() -> String:
	var refusal := CardPacks.change_refusal()
	if refusal != "":
		return refusal
	var record: Variant = JSON.parse_string(FileAccess.get_file_as_string(batch_path())) if left_batch() else null
	var own := ProjectSettings.globalize_path(CommunityCards.own_folder())
	var aside := aside_folder()
	var moves: Array = []
	var installed: Array = []
	var whole := record is Dictionary and SgProtocol.literal(record.get("format"), BATCH_FORMAT) \
		and record.get("moves") is Array and record.get("installed") is Array
	if whole:
		for move: Variant in record["moves"]:
			if not move is Array or move.size() != 3 or not move[0] is String or not move[1] is String \
					or not move[2] in ["move", "copy"] or String(move[0]).get_base_dir() != own \
					or String(move[1]).get_base_dir() != aside or not String(move[0]).ends_with(".zip"):
				whole = false
				break
			moves.append(move)
		for entry: Variant in record["installed"]:
			if not entry is Array or entry.size() != 2 or not entry[0] is String or not entry[1] is String \
					or String(entry[0]).get_base_dir() != own or not String(entry[0]).ends_with(".zip"):
				whole = false
				break
			installed.append(entry)
	if not whole:
		_forget_batch()
		return "The record of the cut-short card transfer could not be read, so nothing was moved. Your set-aside cards are in %s." \
			% GamePaths.shown(aside)
	return "The cut-short card transfer was undone." + _undo(moves, installed)


# ------------------------------------------------------- the connection --

func busy() -> bool:
	return phase != ""


## Ask the host at [param where] for its list: [signal listed] with the
## [method plan], or [signal failed].
func ask_list(where: Dictionary) -> Error:
	return _open(where, "list")


## Fetch [param p]'s `want` from the host at [param where]: [signal
## downloaded] with name → bytes, or [signal failed]. The whole download
## has [constant GRACE_MS] and a second for each [constant MIN_RATE] bytes.
func download(where: Dictionary, p: Dictionary) -> Error:
	if (p.get("want", []) as Array).is_empty():
		return ERR_INVALID_PARAMETER
	var error := _open(where, "download")
	if error == OK:
		_plan = p.duplicate(true)
		_queue = (_plan["want"] as Array).duplicate()
		_zips = {}
		_fetched = 0
		_give_up_at = _opened + GRACE_MS + int(_plan.get("bytes", 0)) * 1000 / MIN_RATE
	return error


func cancel() -> void:
	_close()


func _open(where: Dictionary, kind: String) -> Error:
	if busy() or OS.has_feature("web"):
		return ERR_BUSY
	if not valid_target(where):
		return ERR_INVALID_PARAMETER
	var socket := WebSocketPeer.new()
	socket.supported_protocols = SgProtocol.subprotocols()
	socket.inbound_buffer_size = SgProtocol.MAX_BYTES * 2
	socket.outbound_buffer_size = 65536
	socket.max_queued_packets = 64
	var tls: TLSOptions = where.tls
	var scheme := "wss" if tls != null else "ws"
	var result := socket.connect_to_url("%s://%s:%d" % [scheme, where.address, int(where.port)], tls)
	if result != OK:
		return result
	target = where
	_socket = socket
	phase = kind
	_opened = Time.get_ticks_msec()
	_give_up_at = _opened + CONNECT_MS + REPLY_MS
	_waiting = false
	_due = 0
	_current = []
	_bytes = PackedByteArray()
	_total = -1
	# An open SGManalink connection: the catalogue stays as it is meanwhile.
	CardPacks.lock_catalogue(self)
	return OK


func _process(_delta: float) -> void:
	poll()


func poll() -> void:
	for closing: Dictionary in _closing.duplicate():
		var old: WebSocketPeer = closing["socket"]
		old.poll()
		if old.get_ready_state() == WebSocketPeer.STATE_CLOSED or Time.get_ticks_msec() >= int(closing["until"]):
			old.close(-1)
			_closing.erase(closing)
	if phase == "" or _socket == null:
		return
	var now := Time.get_ticks_msec()
	if now >= _give_up_at:
		_fail(SLOW)
		return
	_socket.poll()
	var state := _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING:
		if now - _opened > CONNECT_MS:
			_fail("Cannot reach the host. Check that it is still running, then try again.")
		return
	if state != WebSocketPeer.STATE_OPEN:
		_fail("The host closed the connection before its cards came. Try again.")
		return
	if _socket.get_selected_protocol() != SgProtocol.SUBPROTOCOL:
		var theirs := SgProtocol.subprotocol_version(_socket.get_selected_protocol())
		_fail(SgCompatibility.protocol_difference(SgProtocol.VERSION, theirs) if theirs > 0 else INVALID)
		return
	for i in 8:
		if phase == "" or _socket.get_available_packet_count() == 0:
			break
		var packet := _socket.get_packet()
		_receive(SgProtocol.decode_payload(packet, 4) if _socket.was_string_packet() else {})
	if phase == "":
		return
	if _waiting and now >= _deadline:
		_fail("The host stopped answering. Try again.")
	elif not _waiting and now >= _due:
		_request(now)


func _request(now: int) -> void:
	var message := {"v": SgProtocol.VERSION, "type": "cards", "access": String(target.access)}
	if phase == "download":
		if _current.is_empty():
			if _queue.is_empty():
				_finish()
				return
			_current = _queue.pop_front()
			_bytes = PackedByteArray()
			_total = -1
			var count := (_plan["want"] as Array).size()
			progressed.emit("Getting the host's %s (%d of %d)…" % [_current[0], count - _queue.size(), count])
		message = {"v": SgProtocol.VERSION, "type": "card", "access": String(target.access),
			"name": String(_current[0]), "offset": _bytes.size()}
	if not SgProtocol.valid(message) or _socket.send_text(SgProtocol.encode(message)) != OK:
		_fail("The card request could not be sent. Try again.")
		return
	_waiting = true
	_deadline = now + REPLY_MS


func _receive(message: Dictionary) -> void:
	if SgProtocol.literal(message.get("type"), "fatal") and SgProtocol.exact(message, ["type", "error"]) \
			and SgViewProtocol.text(message.error, 512):
		_fail(String(message.error))
		return
	if not _waiting:
		_fail(INVALID)
		return
	if phase == "list":
		if not valid_list(message):
			_fail(INVALID)
		elif String(message.error) != "":
			_fail(String(message.error))
		else:
			var p := plan(message.cards, String(message.mark), mine())
			_close()
			listed.emit(p)
		return
	if not valid_chunk(message):
		_fail(INVALID)
		return
	if String(message.error) != "":
		_fail(String(message.error))
		return
	var card := String(_current[0])
	var total := int(message.total)
	# The exact size, at most what the list named, the same for every chunk.
	if String(message.name) != card or int(message.offset) != _bytes.size() or total < 1 \
			or total > int(_current[2]) or (_total != -1 and total != _total):
		_fail("The host's %s changed during the transfer. Try again." % card)
		return
	# The alphabet is checked before decoding: malformed base64 would
	# raise an engine error, not refuse cleanly.
	var data := String(message.data)
	var pattern := RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}\\z")
	if data.is_empty() or data.length() % 4 != 0 or pattern.search(data) == null:
		_fail(INVALID)
		return
	var chunk := Marshalls.base64_to_raw(data)
	if chunk.is_empty() or chunk.size() > MAX_CHUNK or _bytes.size() + chunk.size() > total \
			or Marshalls.raw_to_base64(chunk) != data or _fetched + chunk.size() > MAX_TOTAL:
		_fail(INVALID)
		return
	# A chunk too small to finish in any sane time, unless it is the last.
	if chunk.size() < mini(MIN_CHUNK, total - _bytes.size()):
		_fail(SLOW)
		return
	_total = total
	_bytes.append_array(chunk)
	_fetched += chunk.size()
	_waiting = false
	_due = Time.get_ticks_msec() + PACE_MS
	if _bytes.size() == total:
		_zips[card] = _bytes
		_bytes = PackedByteArray()
		_current = []
		_total = -1
		if _queue.is_empty():
			_finish()


func _finish() -> void:
	var zips := _zips
	_zips = {}
	_close()
	downloaded.emit(zips)


func _fail(reason: String) -> void:
	_close()
	_zips = {}
	failed.emit(reason)


func _close() -> void:
	phase = ""
	_waiting = false
	_queue = []
	_current = []
	_bytes = PackedByteArray()
	_total = -1
	if _socket != null:
		if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_socket.close(1000)
			_closing.append({"socket": _socket, "until": Time.get_ticks_msec() + 1000})
		else:
			_socket.close(-1)
	_socket = null
	CardPacks.unlock_catalogue(self)


func _exit_tree() -> void:
	_close()
	for closing: Dictionary in _closing:
		(closing["socket"] as WebSocketPeer).close(-1)
	_closing.clear()
