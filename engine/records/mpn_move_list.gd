class_name MpnMoveList
extends RefCounted
## [QoL] AN MPN RECORD AS A MOVE LIST a person reads (the owner, 2026-10-24:
## "try to make it human readable and lapidary!"): the game told turn by
## turn, under each turn its player, under each phase one action a line —
## untap, upkeep, draw, main 1, combat, main 2, end — a phase where nothing
## happened left out, and every symbol it uses explained at its start ("The
## file should explain all used symbols at the beginning"). The record's
## file stays MPN 0.1 (the owner's choice); this is a READING of it, as
## chess's move list is of a game, made from the record's public events and
## states alone: no rules, no commands run, nothing the record does not say.
##
## `docs/mpn-move-list.md` defines it exactly, for any implementation to
## render a record to the same text byte for byte; the notation is
## [constant LEGEND]. Every value of a record is read defensively: the codec
## validates the state, not every event's payload, so a field of the wrong
## type reads as missing, never as an error.

const ARROW := "→"
const ATTACK := "⚔"
## The phase each recorded step belongs to.
const PHASES := {"untap": "untap", "upkeep": "upkeep", "draw": "draw", "main1": "main 1",
	"combat_begin": "combat", "declare_attackers": "combat", "declare_blockers": "combat",
	"first_strike_damage": "combat", "combat_damage": "combat", "combat_end": "combat",
	"main2": "main 2", "end": "end", "cleanup": "end"}
## Where a card that left play went, by the zone the record shows it in.
const MARKS := {"graveyard": "†", "exile": "✕", "hand": "↩", "library": "↧"}
## A card gone out of sight: to a hand or a library unrevealed, or a token
## that ceased to exist.
const HIDDEN := "⇥"
const RESULTS := {"1-0": "1-0", "0-1": "0-1", "1/2-1/2": "½-½"}
## EVERY SYMBOL THE MOVE LIST USES, explained where it begins, in the order
## a reader meets them.
const LEGEND: Array = [
	["Plains", "a land played"],
	["Savannah Lions", "a spell cast (it resolved unless told otherwise)"],
	["→", "its targets; after damage, the life the player has left (→ B 12)"],
	["uses", "an activated ability (uses Prodigal Sorcerer → B)"],
	["X=5", "the X a spell was cast with"],
	["⚔", "attacks; \"Wall blocks Knight\" a block"],
	["Egg deals 2", "damage from a permanent or a trigger, not a spell"],
	["†", "died, or went to its owner's graveyard"],
	["✕", "exiled (removed from the game)"],
	["↩", "returned to its owner's hand"],
	["↧", "put into a library"],
	["⇥", "left play out of sight (to a hand or a library), or a token gone"],
	["+Serra Angel", "put into play without being cast or played"],
	["W +4 → 24", "a life change no damage tells (a gain, a loss)"],
	["burns 1 → W 19", "mana burn: life lost for mana left unused"],
	["#", "the life that ended the game, as chess's mate"],
	["×2", "two of one name (⚔ Goblin ×2), or the same line twice in a row"],
	["[B]", "an action by the player whose turn it is not"],
	["{…}", "a comment written in the record"],
	["—", "a turn in which nothing public happened"],
]
## The last line of the symbols' block.
const NOT_TOLD := "Taps, untaps, mana and each turn's first draw are not told."


## The move list of [param document] ([method MpnCodec.parse]'s result) as
## text: the tags, the symbols, each turn under its player with the phase in
## a column of its own (for a monospace reader), then the result.
static func text(document: Dictionary) -> String:
	var read := read_game(document)
	var out: PackedStringArray = []
	for tag_line in read["tags"]:
		out.append('[%s "%s"]' % [tag_line[0], String(tag_line[1]).replace("\\", "\\\\").replace("\"", "\\\"")])
	out.append("")
	out.append("Symbols")
	for entry in LEGEND:
		out.append("  %s%s" % [String(entry[0]).rpad(16), entry[1]])
	out.append("  " + NOT_TOLD)
	out.append("")
	for turn in read["turns"]:
		out.append(String(turn["heading"]))
		if (turn["lines"] as Array).is_empty():
			out.append("  —")
		for line in turn["lines"]:
			out.append("  %s%s" % [String(line[0]).rpad(9), line[1]])
	out.append("")
	out.append(String(read["result"]))
	return "\n".join(out) + "\n"


## The move list of [param document] as data, for a screen to lay out:
## `{tags: [[tag, value]], turns: [{heading, label, player, lines: [[phase,
## words]]}], result}` — `label` "Turn 3" (or "Before"), a phase named on
## its first line only ("" after). The symbols are [constant LEGEND].
static func read_game(document: Dictionary) -> Dictionary:
	return _Reading.new(document).read()


## The players' tags: the first letter of each name, upper-cased, when both
## names have one and they differ; else P1 and P2.
static func tags_of(headers: Dictionary) -> Array[String]:
	var first: Array[String] = []
	for key in ["Player.P1", "Player.P2"]:
		first.append(_first_letter(clean(headers.get(key, ""))))
	if first[0] == "" or first[1] == "" or first[0] == first[1]:
		return ["P1", "P2"] as Array[String]
	return first


static func _first_letter(name_text: String) -> String:
	for i in name_text.length():
		var c := name_text.substr(i, 1)
		if c.to_upper() != c.to_lower():
			return c.to_upper()
	return ""


## [param value] as one line of text: a string as it is, a number as its
## digits, anything else ""; control characters (a line break could forge a
## turn in the text) become spaces.
static func clean(value: Variant) -> String:
	var said := ""
	if value is String or value is StringName:
		said = String(value)
	elif value is int or value is float:
		said = str(value)
	var out := PackedStringArray()
	for i in said.length():
		var code := said.unicode_at(i)
		out.append(" " if code < 32 or code == 127 else said.substr(i, 1))
	return "".join(out).strip_edges()


## "A, A, B" as "A ×2, B", the order kept.
static func counted(names: Array) -> String:
	var runs: Array = []
	for name_text in names:
		if not runs.is_empty() and runs[-1][0] == name_text:
			runs[-1][1] += 1
		else:
			runs.append([name_text, 1])
	var out: PackedStringArray = []
	for run in runs:
		out.append(String(run[0]) if int(run[1]) == 1 else "%s ×%d" % [run[0], run[1]])
	return ", ".join(out)


static func _int(value: Variant, otherwise: int) -> int:
	return int(value) if value is int or value is float else otherwise


static func _id(value: Variant) -> String:
	return String(value) if value is String else ""


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _list(value: Variant) -> Array:
	return value if value is Array else []


## One action told: its words, whose it is when not the turn's player's, the
## phase, the handles it names, the lives it left, what left play of it.
class _Action:
	var words := ""
	var actor := ""
	var phase := ""
	var index := 0
	var ids: Array = []
	var lives: Array = []       # [tag, life, lethal]
	var gone: Array = []        # [name, mark]
	var blocked_id := ""
	var blockers: Array = []
	## A life change of its own line: the tag, its life after.
	var own_tag := ""
	var own_life := 0
	var own_lethal := false
	## A land seen entering play, told as "+Forest" unless played.
	var land_entering := false

	## The words, then what left play of it ("Bolt → Knight †"; the others
	## after "; "), then the lives it left ("→ B 12").
	func render() -> String:
		var told := words
		if lives.size() == 1 and gone.is_empty():
			var aimed := " %s %s" % [MpnMoveList.ARROW, lives[0][0]]
			# A spell aimed at the player it hurt: "Bolt → G 17", not
			# "Bolt → G → G 17".
			if told.ends_with(aimed):
				told = told.left(told.length() - aimed.length())
		var by_mark := {}
		var order: Array = []
		for entry in gone:
			if not by_mark.has(entry[1]):
				by_mark[entry[1]] = []
				order.append(entry[1])
			by_mark[entry[1]].append(entry[0])
		var others: PackedStringArray = []
		var marked := false
		for mark in order:
			var rest: Array = (by_mark[mark] as Array).duplicate()
			if not marked and told != "":
				for name_text in rest:
					if told.ends_with(String(name_text)):
						told += " " + String(mark)
						rest.erase(name_text)
						marked = true
						break
			if not rest.is_empty():
				others.append("%s %s" % [mark, MpnMoveList.counted(rest)])
		if not others.is_empty():
			told = "; ".join(others) if told == "" else told + "; " + "; ".join(others)
		if own_tag != "":
			told += " %s %d%s" % [MpnMoveList.ARROW, own_life, "#" if own_lethal else ""]
		elif not lives.is_empty():
			var said: PackedStringArray = []
			for entry in lives:
				said.append("%s %d%s" % [entry[0], entry[1], "#" if entry[2] else ""])
			told += " %s %s" % [MpnMoveList.ARROW, ", ".join(said)]
		return (("[%s] " % actor if actor != "" else "") + told).strip_edges()


## A record read through once.
class _Reading:
	var headers: Dictionary
	var records: Array
	var tags: Array[String]
	var seats_named := true
	var objects := {}
	## Rows the record has removed, kept for their names (MPN 0.1 §7: "a
	## reader may retain retired rows in a separate historical lookup").
	var history := {}
	## Names of permanents the last state removed, for a leave or a die that
	## names no card (records written before 2026-10-24 did not).
	var just_removed: Array = []
	var stack := {}
	var lives: Array = [null, null]
	var pending := {}           # player index -> [life before, life after, phase]
	var turns: Array = []       # [turn, active, actions]
	var current: Array = []
	var active := 0
	var phase := ""
	var cast_names: Array = []
	## This turn's handles -> the latest action naming them; attackers ->
	## their attack.
	var owner_of := {}
	var attack_of := {}
	var first_draw_told := false
	var result := ""

	func _init(document: Dictionary) -> void:
		headers = MpnMoveList._dict(document.get("headers", {}))
		records = MpnMoveList._list(document.get("records", []))
		tags = MpnMoveList.tags_of(headers)
		seats_named = tags[0] != "P1"

	func _row(id: String) -> Dictionary:
		return MpnMoveList._dict(objects.get(id, history.get(id, {})))

	func _name(id: String) -> String:
		var said := MpnMoveList.clean(_row(id).get("name", ""))
		return said if said != "" else (id if id != "" else "?")

	func _tag_of(player: Variant) -> int:
		var said := MpnMoveList._id(player)
		return int(said.right(1)) - 1 if said == "P1" or said == "P2" else -1

	func _who(target: Variant) -> String:
		var aim := MpnMoveList._dict(target)
		var pid := _tag_of(aim.get("player", ""))
		return tags[pid] if pid >= 0 else _name(MpnMoveList._id(aim.get("object", "")))

	func _add(words: String, actor := -1, ids: Array = []) -> _Action:
		if current.is_empty():
			return null
		var action := _Action.new()
		action.words = words
		action.actor = tags[actor] if actor >= 0 and actor != int(current[1]) else ""
		action.phase = phase
		action.ids = ids
		action.index = (current[2] as Array).size()
		(current[2] as Array).append(action)
		for id in ids:
			owner_of[id] = action
		return action

	func _last() -> _Action:
		if current.is_empty() or (current[2] as Array).is_empty():
			return null
		return (current[2] as Array)[-1]

	## Life changes no damage told: each a line of its own, in the phase it
	## happened in — all but [param keep]'s, which the action at hand tells.
	func _flush(keep := -1) -> void:
		for pid in pending.keys():
			if int(pid) == keep:
				continue
			var change: Array = pending[pid]
			var delta := int(change[1]) - int(change[0])
			var shown := phase
			phase = String(change[2])
			var action := _add("%s %s%d" % [tags[pid], "+" if delta > 0 else "−", absi(delta)])
			phase = shown
			if action != null:
				action.own_tag = tags[pid]
				action.own_life = int(change[1])
		var kept: Variant = pending.get(keep)
		pending.clear()
		if kept != null:
			pending[keep] = kept

	func _start_turn(number: int) -> void:
		_flush()
		current = [number, active, []]
		turns.append(current)
		cast_names.clear()
		owner_of.clear()
		attack_of.clear()
		first_draw_told = false

	func _state(data: Dictionary) -> void:
		# The active player carries over a patch that leaves it out (an extra
		# turn keeps it).
		if data.has("active"):
			active = clampi(MpnMoveList._int(data["active"], active), 0, 1)
		var number := MpnMoveList._int(data.get("turn"), -1) if data.has("turn") else -1
		# A turn begins when its number changes: a writer may repeat the whole
		# state in every record (MPN 0.1 §5).
		if data.has("turn") and (current.is_empty() or number != int(current[0])):
			_start_turn(number)
		elif data.has("active") and not current.is_empty():
			current[1] = active
		if data.has("step"):
			var step := MpnMoveList.clean(data["step"])
			phase = String(MpnMoveList.PHASES.get(step, step))
		var removing := MpnMoveList._list(data.get("removed", []))
		if not removing.is_empty():
			just_removed.clear()
		for value in removing:
			var id := MpnMoveList._id(value)
			var row := MpnMoveList._dict(objects.get(id, {}))
			if not row.is_empty():
				history[id] = row
				if MpnMoveList.clean(row.get("zone", "")) == "battlefield":
					just_removed.append(_name(id))
			objects.erase(id)
		for value in MpnMoveList._list(data.get("objects", [])):
			var row := MpnMoveList._dict(value)
			var id := MpnMoveList._id(row.get("id", ""))
			if id != "":
				objects[id] = row     # a whole-row replacement (MPN 0.1 §7)
		for value in MpnMoveList._list(data.get("stack", [])):
			var entry := MpnMoveList._dict(value)
			stack[MpnMoveList._id(entry.get("source", ""))] = entry
		var players := MpnMoveList._list(data.get("players", []))
		for pid in mini(players.size(), 2):
			var player := MpnMoveList._dict(players[pid])
			if not player.has("life") or not (player["life"] is int or player["life"] is float):
				continue
			var life := int(player["life"])
			if lives[pid] != null and life != int(lives[pid]):
				var before: int = int(pending[pid][0]) if pending.has(pid) else int(lives[pid])
				pending[pid] = [before, life, phase]
			lives[pid] = life

	func _damage(data: Dictionary) -> void:
		var pid := _tag_of(data.get("target", ""))
		if pid < 0 or not pending.has(pid) or current.is_empty():
			return
		var source := MpnMoveList._id(data.get("source", ""))
		var owner := _combat_line(source)
		if owner == null and source != "" and owner_of.has(source):
			owner = owner_of[source]
		if owner == null and source != "":
			# A permanent's or a trigger's damage, no action of its own told:
			# "Dingus Egg deals 2", by the source's controller.
			var controller := MpnMoveList._int(_row(source).get("controller", -1), -1)
			owner = _add("%s deals %d" % [_name(source), maxi(MpnMoveList._int(data.get("amount", 0), 0), 0)],
				controller, [source])
		if owner == null:
			owner = _last()
		if owner == null:
			return
		var after := int(pending[pid][1])
		pending.erase(pid)
		for entry in owner.lives:
			if entry[0] == tags[pid]:
				entry[1] = after
				return
		owner.lives.append([tags[pid], after, false])

	## Where an attacker's damage ([param source]) is told: on its attack, or
	## the blocks after it, when nothing else was done in the combat since;
	## else on a line of its own closing the combat ("→ B 5") — never on a
	## pump or a spell cast in between, which did not deal it. Null for a
	## source that is no attacker of this turn.
	func _combat_line(source: String) -> _Action:
		if source == "" or not attack_of.has(source):
			return null
		var actions: Array = current[2]
		var at := (attack_of[source] as _Action).index
		while at + 1 < actions.size() and (actions[at + 1] as _Action).blocked_id != "":
			at += 1
		if at == actions.size() - 1:
			return actions[at]
		var last: _Action = actions[-1]
		if last.words == "" and last.gone.is_empty() and last.phase == phase:
			return last
		return _add("")

	## Mana burn tells the life it cost: "burns 1 → C 15".
	func _mana_burn(data: Dictionary) -> void:
		var pid := _tag_of(data.get("player", ""))
		_flush(pid)
		var amount := MpnMoveList._int(data.get("amount", 0), 0)
		var action := _add("burns %d" % amount if pid < 0 else "burns %d %s %s" % [amount, MpnMoveList.ARROW, tags[pid]], pid)
		if action != null and pid >= 0 and pending.has(pid):
			action.lives.append([tags[pid], int(pending[pid][1]), false])
			pending.erase(pid)

	## A card leaving play marks the action before it, in the same phase;
	## else a line of its own ("† Bog Imp").
	func _gone(kind: String, data: Dictionary) -> void:
		var id := MpnMoveList._id(data.get("object", ""))
		var gone_name := _name(id)
		if id == "":
			if just_removed.is_empty():
				return
			gone_name = String(just_removed[0])
			if kind == "die":
				just_removed.pop_front()
		var zone := ""
		if objects.has(id):
			zone = MpnMoveList.clean(MpnMoveList._dict(objects[id]).get("zone", ""))
		if kind == "leave" and zone == "battlefield":
			return
		# Still public: where it went; out of sight: to a hand or a library
		# unrevealed, or a token gone.
		var mark := "†" if kind == "die" else String(MpnMoveList.MARKS.get(zone, MpnMoveList.HIDDEN))
		var entry := [gone_name, mark]
		var last := _last()
		if last == null or last.phase != phase or last.own_tag != "":
			last = _add("")
			if last == null:
				return
		if kind == "die":
			# Its leave told it gone out of sight: a death says more.
			var hidden := [gone_name, MpnMoveList.HIDDEN]
			if last.gone.has(hidden):
				last.gone.erase(hidden)
			if last.gone.has(entry):
				return
		last.gone.append(entry)

	func _event(kind: String, data: Dictionary) -> void:
		var actor := _tag_of(data.get("player", ""))
		match kind:
			"land":
				var id := MpnMoveList._id(data.get("object", ""))
				var entering: _Action = owner_of.get(id) if id != "" else null
				if entering != null and entering.land_entering:
					entering.words = _name(id)
					entering.land_entering = false
				else:
					_add(_name(id), actor, [id] if id != "" else [])
			"cast", "activate":
				var id := MpnMoveList._id(data.get("object", ""))
				var entry := MpnMoveList._dict(stack.get(id, {}))
				var spell := MpnMoveList.clean(entry.get("name", ""))
				var words := spell if spell != "" else _name(id)
				if kind == "activate":
					words = "uses " + words
				var x := MpnMoveList._int(entry.get("x", 0), 0)
				if x > 0:
					words += " X=%d" % x
				var targets: PackedStringArray = []
				for target in MpnMoveList._list(entry.get("targets", [])):
					targets.append(_who(target))
				if not targets.is_empty():
					words += " %s %s" % [MpnMoveList.ARROW, ", ".join(targets)]
				_add(words, actor, [id] if id != "" else [])
				if kind == "cast" and spell != "":
					cast_names.append(spell)
			"attack":
				var ids: Array = []
				var names: Array = []
				for value in MpnMoveList._list(data.get("objects", [])):
					var id := MpnMoveList._id(value)
					if id != "":
						ids.append(id)
						names.append(_name(id))
				if not ids.is_empty():
					var action := _add("%s %s" % [MpnMoveList.ATTACK, MpnMoveList.counted(names)], actor, ids)
					if action != null:
						for id in ids:
							attack_of[id] = action
			"block":
				var blocker := MpnMoveList._id(data.get("blocker", ""))
				var attacker := MpnMoveList._id(data.get("attacker", ""))
				if blocker == "":
					return
				var last := _last()
				if last != null and last.blocked_id == attacker and last.phase == phase:
					last.blockers.append(_name(blocker))
					last.words = "%s block %s" % [MpnMoveList.counted(last.blockers), _name(attacker)]
				else:
					var action := _add("%s blocks %s" % [_name(blocker), _name(attacker)])
					if action != null:
						action.blocked_id = attacker if attacker != "" else "?"
						action.blockers = [_name(blocker)]
			"enter":
				var id := MpnMoveList._id(data.get("object", ""))
				var entered := _name(id)
				var types := MpnMoveList._list(_row(id).get("types", []))
				if types.has("land"):
					if id != "" and owner_of.has(id):
						return      # its play is told
					var action := _add("+" + entered, actor, [id] if id != "" else [])
					if action != null:
						action.land_entering = true
				elif cast_names.has(entered):
					cast_names.erase(entered)
				else:
					_add("+" + entered, actor, [id] if id != "" else [])
			"discard":
				_add("discards " + _name(MpnMoveList._id(data.get("object", ""))), actor)
			"draw":
				var count := MpnMoveList._int(data.get("count", 1), 1)
				# The turn's first draw, the active player's in the draw step.
				if not current.is_empty() and count == 1 and phase == "draw" and not first_draw_told \
						and (actor == -1 or actor == int(current[1])):
					first_draw_told = true
					return
				_add("draws %d" % count, actor)
			"reveal":
				var cards: PackedStringArray = []
				for card in MpnMoveList._list(data.get("cards", [])):
					cards.append(MpnMoveList.clean(card))
				_add("reveals " + ", ".join(cards), actor)
			"regenerate":
				_add(_name(MpnMoveList._id(data.get("object", ""))) + " regenerates", actor)
			"comment":
				_add("{%s}" % MpnMoveList.clean(data.get("text", "")))
			"result":
				result = String(MpnMoveList.RESULTS.get(MpnMoveList.clean(data.get("result", "")), ""))

	## The "#": on the last life told of the player who lost, when it is 0 or
	## less — not on every life at 0, from which a player may still come back.
	func _mark_lethal() -> void:
		var losers: Array = []
		match result:
			"1-0": losers.append(tags[1])
			"0-1": losers.append(tags[0])
			"½-½": losers.append_array([tags[0], tags[1]])
		for tag in losers:
			var found := false
			for t in range(turns.size() - 1, -1, -1):
				var actions: Array = turns[t][2]
				for a in range(actions.size() - 1, -1, -1):
					var action: _Action = actions[a]
					if action.own_tag == tag:
						action.own_lethal = action.own_life <= 0
						found = true
					else:
						for entry in action.lives:
							if entry[0] == tag:
								entry[2] = int(entry[1]) <= 0
								found = true
					if found:
						break
				if found:
					break

	func read() -> Dictionary:
		for value in records:
			var record := MpnMoveList._dict(value)
			var kind := MpnMoveList.clean(record.get("kind", ""))
			var data := MpnMoveList._dict(record.get("data", {}))
			match kind:
				"state":
					_state(data)
				"damage":
					_damage(data)
				"mana_burn":
					_mana_burn(data)
				"die", "leave":
					# A card leaving play belongs to the action before it, so
					# the life it changed is told after it, not between.
					_gone(kind, data)
				"tap", "untap", "mana", "close":
					pass
				_:
					_flush()
					_event(kind, data)
		_flush()
		_mark_lethal()
		var tag_lines: Array = []
		for i in 2:
			tag_lines.append([tags[i], MpnMoveList.clean(headers.get("Player.P%d" % (i + 1), ""))])
		var started := MpnMoveList.clean(headers.get("Started", ""))
		if started.length() >= 10:
			tag_lines.append(["Date", started.left(10)])
		tag_lines.append(["Result", result if result != "" else "*"])
		var told: Array = []
		for turn in turns:
			var seat := int(turn[1])
			var who := MpnMoveList.clean(headers.get("Player.P%d" % (seat + 1), ""))
			if who == "":
				who = tags[seat]
			elif not seats_named:
				who += " (%s)" % tags[seat]
			var number := int(turn[0])
			var heading := ("Turn %d · %s" % [number, who]) if number > 0 else "Before the game · %s" % who
			# One line per action; the same line again in the same phase
			# counted on it ("×2"), its count kept apart from the words.
			var lines: Array = []   # [phase, words, times]
			for action in turn[2]:
				var said := (action as _Action).render()
				if said == "":
					continue
				if not lines.is_empty() and lines[-1][0] == action.phase and lines[-1][1] == said:
					lines[-1][2] += 1
				else:
					lines.append([action.phase, said, 1])
			var shown := ""
			var out: Array = []
			for line in lines:
				var phase_name := String(line[0])
				out.append([phase_name if phase_name != shown else "",
					String(line[1]) + (" ×%d" % int(line[2]) if int(line[2]) > 1 else "")])
				shown = phase_name
			told.append({"heading": heading, "lines": out, "player": who,
				"label": ("Turn %d" % number) if number > 0 else "Before"})
		return {"tags": tag_lines, "turns": told,
			"result": result if result != "" else "* (unfinished)"}
