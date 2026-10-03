extends RefCounted
## THE DAMAGE REPLACEMENT SUITE (Pack 8, the Mirage block) — one registry
## of replacement and prevention effects aimed at DAMAGE EVENTS, whoever
## the victim is: a player, a creature, "you and/or creatures you control",
## "any target", or every victim at all.
##
## WHY ONE MORE LIST. The engine already carries a dozen damage gates, and
## every one of them is keyed to ONE kind of victim: the seat-level
## [member MtgPlayer.damage_replacements] (Forcefield, Nova Pentacle) only
## ever sees damage aimed at that player, the creature fields (Jade
## Monolith's redirect, Rock Hydra's counters, a prevention pool) only
## damage aimed at that creature. The Mirage block prints the shapes those
## cannot hold:
##
## - "The next time a source of your choice would deal damage to you AND/OR
##   CREATURES YOU CONTROL this turn, prevent that damage" (Shadowbane) —
##   ONE shield over several victims, used up by ONE damage event however
##   many of them that event touches (CR 615.8: "the next instance of damage
##   from that source").
## - "... to ANY TARGET" (Circle of Despair, Honorable Passage) and "... to
##   enchanted creature" (Kithkin Armor) — the same shield on one victim of
##   either kind.
## - "The next time a source of your choice would deal damage THIS TURN,
##   that damage is dealt to that source's controller instead" (Reflect
##   Damage) — a replacement on the SOURCE, every victim.
## - DAMAGE MODIFIERS: "If a spell would deal damage ..., it deals that much
##   damage minus 1 instead" (Benevolent Unicorn), "... combat damage to a
##   creature this turn, it deals double that damage instead" (Blind Fury),
##   "the next time that source would deal damage this turn, it deals double
##   that damage instead" (Desperate Gambit) — CR 614.1a replacements that
##   change the AMOUNT.
## - "If damage would be dealt to this creature, put that many -1/-1
##   counters on it instead" (Lichenthrope) — damage replaced by counters.
## - "The next 1 damage that would be dealt to this creature this turn is
##   dealt to ANY TARGET instead" (Zhalfirin Crusader) — metered
##   redirection, generalising Personal Incarnation's to-its-owner points.
## - "Prevent the next 1 damage that would be dealt to this creature BY
##   TORRENT OF LAVA this turn" — a metered shield keyed to one source.
## - durations longer than the turn ("until your next upkeep", Soul Echo).
##
## HOW IT JOINS THE CHAIN. Every entry is offered as ONE MORE GATE — kind
## `&"fx"` — in the two CR 616.1 walks [MtgGame] already runs
## ([method MtgGame._damage_gates] for a player, [method
## MtgGame._creature_damage_gates] for a creature), so the affected player
## or the affected object's controller ORDERS these against every other
## replacement and prevention exactly as the rule says. Nothing here decides
## an order; [method collect] only sorts the default hint (which every
## heuristic seat takes): what helps the victim first — decreases,
## prevention, redirection — and what hurts it last — increases, and
## counters (which a Lichenthrope would rather a prevention pool absorbed
## first).
##
## ENTRIES ARE DICTIONARIES, like every other damage gate's, so the search
## journal ([UndoLog]) and the rewind ([GameSnapshot]) cover them with no
## new state class: [member MtgGame.damage_effects] is recorded whole before
## any entry in it changes. [member MtgGame.static_damage_effects] is
## DERIVED — rebuilt by every [method ContinuousEffects.recalculate] from the
## statics that write it ([method MtgGame.add_static_damage_effect]) — and
## is never journaled (PRIMARY STATE ONLY, `engine/undo_log.gd`).
##
## THE SPEC ([method MtgGame.add_damage_effect]):
## [codeblock]
##   "desc"        String   card English — the CR 616.1 prompt line and the log
##   "card"        String   the card that made it (public, for the portrait badge)
##   "controller"  int      the player who controls the effect (-1: nobody)
##   "kind"        &"prevent" | &"modify" | &"redirect" | &"counters" | &"replace"
##
##   WHICH DAMAGE (every key optional; absent = any)
##   "source"        CardInstance  the chosen source (sets source_id/source_stamp)
##   "source_id"     int           ... or by id; "source_stamp" -1 = any incarnation
##   "source_filter" Callable(game, source: CardInstance) -> bool, re-read
##                   LIVE when the damage would be dealt (CR 609.7b)
##   "victims"       Array of TargetRef / CardInstance / {"player": pid} /
##                   {"id": int, "stamp": int}; empty = every victim
##   "creatures_of"  int   also covers every creature that player controls
##                         when the damage would be dealt ("you and/or
##                         creatures you control")
##   "combat_only"   bool  combat damage only (Blind Fury)
##   "spell_only"    bool  damage from a SPELL only (Benevolent Unicorn)
##   "filter"        Callable(game, packet: DamagePacket) -> bool, anything else
##
##   WHAT HAPPENS
##   &"modify"    "factor" int (default 1), "delta" int (default 0): the event
##                deals remaining * factor + delta instead (never below 0)
##   &"prevent"   "points" int: 0 = the whole event; N = the next N damage
##   &"redirect"  "to": TargetRef / CardInstance / {"player"} / {"id","stamp"},
##                or "to_source_controller": true; "points" as for prevent
##   &"counters"  "counter" String: that many counters of this kind instead
##   &"replace"   "apply": Callable(game, packet) -> int — the
##                MtgPlayer.damage_replacements contract: -1 carry on, >= 0
##                the event ended and that much was dealt
##   "then"       Callable(game, packet, amount: int) -> void — the rider,
##                run right after the gate with the amount it prevented,
##                redirected or turned into counters (CR 615.5)
##
##   HOW LONG
##   "one_shot"   bool  used up by the first damage EVENT it applies to — the
##                       "the next time ..." family (CR 615.8). A metered entry
##                       ("points") is used up by its points instead.
##   "lasts"      &"turn" (default, cleanup ends it) | &"upkeep" (until
##                "lasts_pid"'s next upkeep, CR 611.2b) | &"indefinite"
## [/codeblock]
##
## ONE DAMAGE EVENT ([member MtgGame._damage_event_serial]). A one-shot entry
## is spent by an EVENT, not by a packet: the engine deals simultaneous
## damage as one packet per victim, so "the next time Pestilence would deal
## damage to you and/or creatures you control" must stop all of them, and
## then nothing after. The serial is bumped when a damage event begins —
## each top-level [method MtgGame.deal_damage], each simultaneous bracket
## ([method MtgGame.begin_simultaneous]: the combat-damage waves, a
## Pestilence, the 1997 window's landing), and once per stack resolution (one
## spell's or ability's damage is dealt at once, CR 608.2). A spent entry
## keeps applying for the rest of its own event and is pruned when the next
## one begins.
##
## CR 614.5 / 616.1f: a replacement applies to one event once. Each entry
## that applies leaves its key in the packet's
## [member DamagePacket.applied_creature_redirects] list (the field every
## redirect and split already copies onto the packet it creates), so the
## damage Reflect Damage turns on the source's controller cannot be
## reflected again, and a Benevolent Unicorn does not shave the same Bolt a
## second time after a redirect.
##
## CR 615.12: damage that "can't be prevented" (Whippoorwill, Lava Burst —
## [member CardInstance.damage_unpreventable_this_turn],
## [member DamagePacket.unpreventable_to_creatures]) is neither prevented
## nor "dealt instead to another permanent or player" by an entry here, and
## such a shield is not used up by it. A MODIFIER and the counters
## replacement still apply: they prevent nothing and move nothing.

const KIND_PREVENT := &"prevent"
const KIND_MODIFY := &"modify"
const KIND_REDIRECT := &"redirect"
const KIND_COUNTERS := &"counters"
const KIND_REPLACE := &"replace"
const KINDS: Array[StringName] = [KIND_PREVENT, KIND_MODIFY, KIND_REDIRECT,
	KIND_COUNTERS, KIND_REPLACE]


# ------------------------------------------------------------ the spec --

## [param spec] made canonical: the source and victims as ids, the
## destination as a value, the defaults filled. Returns `{}` and logs
## nothing when the spec cannot describe an effect (an unknown kind, a
## redirect with nowhere to go) — the caller turns that into a refusal.
static func normalize(g: MtgGame, spec: Dictionary) -> Dictionary:
	var kind := StringName(spec.get("kind", KIND_PREVENT))
	if not KINDS.has(kind):
		return {}
	var e := {
		"desc": String(spec.get("desc", "Damage effect")),
		"card": String(spec.get("card", "")),
		"controller": int(spec.get("controller", -1)),
		"kind": kind,
		"source_id": int(spec.get("source_id", -1)),
		"source_stamp": int(spec.get("source_stamp", -1)),
		"victims": [],
		"creatures_of": int(spec.get("creatures_of", -1)),
		"combat_only": bool(spec.get("combat_only", false)),
		"spell_only": bool(spec.get("spell_only", false)),
		"factor": int(spec.get("factor", 1)),
		"delta": int(spec.get("delta", 0)),
		"points": maxi(int(spec.get("points", 0)), 0),
		"counter": String(spec.get("counter", "-1/-1")),
		"to_source_controller": bool(spec.get("to_source_controller", false)),
		"one_shot": bool(spec.get("one_shot", false)),
		"lasts": StringName(spec.get("lasts", &"turn")),
		"lasts_pid": int(spec.get("lasts_pid", -1)),
		"spent_event": -1,
	}
	e["points_left"] = e["points"]
	var source: Variant = spec.get("source")
	if source is CardInstance:
		var chosen: CardInstance = source
		e["source_id"] = chosen.id
		# A PERMANENT is one object until it changes zones (CR 400.7), so the
		# stamp pins the shield to this incarnation. A SPELL is named for
		# itself AND for the permanent it becomes (CR 609.7a), so it is not.
		e["source_stamp"] = chosen.layer_timestamp \
			if chosen.zone == Mtg.Zone.BATTLEFIELD else -1
	for key in ["source_filter", "filter", "apply", "then"]:
		var cb: Variant = spec.get(key)
		if cb is Callable and (cb as Callable).is_valid():
			e[key] = cb
	if kind == KIND_REPLACE and not e.has("apply"):
		return {}
	for victim in spec.get("victims", []):
		var key := victim_key(g, victim)
		if not key.is_empty():
			e["victims"].append(key)
	if kind == KIND_REDIRECT:
		if not e["to_source_controller"]:
			var to := victim_key(g, spec.get("to"))
			if to.is_empty():
				return {}
			e["to"] = to
	return e


## A victim or destination as a value — `{"player": pid}` or
## `{"id": int, "stamp": int}` (the battlefield incarnation, CR 400.7) —
## from a [TargetRef], a [CardInstance] or such a Dictionary. `{}` for
## anything else.
static func victim_key(g: MtgGame, what: Variant) -> Dictionary:
	if what is TargetRef:
		var ref: TargetRef = what
		if ref.is_player:
			return {"player": ref.player_id}
		if ref.is_damage or ref.is_ability:
			return {}
		var inst := g.find_instance(ref.instance_id)
		return {"id": ref.instance_id,
			"stamp": inst.layer_timestamp if inst != null else -1}
	if what is CardInstance:
		var card: CardInstance = what
		return {"id": card.id, "stamp": card.layer_timestamp}
	if what is Dictionary:
		var d: Dictionary = what
		if d.has("player"):
			return {"player": int(d["player"])}
		if d.has("id"):
			return {"id": int(d["id"]), "stamp": int(d.get("stamp", -1))}
	return {}


## The key an entry leaves on a packet it applied to (CR 614.5). A static
## entry is rebuilt with a new id every recalculation, so it is keyed by
## the source that writes it instead.
static func guard_key(e: Dictionary) -> String:
	if e.has("static_key"):
		return "fx:s:" + String(e["static_key"])
	return "fx:%d" % int(e.get("id", -1))


# ------------------------------------------------------ the candidates --

## Could any entry touch a packet at all? The cheap front door both chains
## ask before building a candidate list — two emptiness tests.
static func any(g: MtgGame) -> bool:
	return not g.damage_effects.is_empty() or not g.static_damage_effects.is_empty()


## Append a gate `{"kind": &"fx", "entry": e}` for every entry that applies
## to [param packet] right now: the ones that help the victim to
## [param front], the ones that hurt it to [param late] (see the class
## note — this is the default hint, not a decision).
static func collect(g: MtgGame, packet: DamagePacket, front: Array[Dictionary],
		late: Array[Dictionary]) -> void:
	for list in [g.damage_effects, g.static_damage_effects]:
		for e in list:
			if not applies(g, packet, e):
				continue
			var gate := {"kind": &"fx", "entry": e}
			if _hurts_victim(packet, e):
				late.append(gate)
			else:
				front.append(gate)


static func _hurts_victim(packet: DamagePacket, e: Dictionary) -> bool:
	match StringName(e["kind"]):
		KIND_MODIFY:
			return _modified(packet.remaining(), e) > packet.remaining()
		KIND_COUNTERS:
			return true
	return false


## Does entry [param e] apply to [param packet] right now? PURE — asked when
## the candidate list is built and again after every gate taken (CR 616.1f
## re-applies the rule only to what is STILL applicable).
static func applies(g: MtgGame, packet: DamagePacket, e: Dictionary) -> bool:
	var source: CardInstance = packet.source
	var amount := packet.remaining()
	if source == null or packet.target == null or amount <= 0:
		return false
	if packet.applied_creature_redirects.has(guard_key(e)):
		return false   # CR 614.5: once per event
	if bool(e["one_shot"]) and int(e["spent_event"]) >= 0 \
			and int(e["spent_event"]) != g._damage_event_serial:
		return false   # used up by an earlier event (CR 615.8)
	if int(e["points"]) > 0 and int(e["points_left"]) <= 0:
		return false
	if e.has("static_key") and not _static_still_written(g, e):
		return false   # its source left, or lost the ability, mid-event
	if int(e["source_id"]) >= 0:
		if packet.source_id() != int(e["source_id"]):
			return false
		if int(e["source_stamp"]) >= 0 and packet.source_timestamp != int(e["source_stamp"]):
			return false
	if e.has("source_filter") and not bool(e["source_filter"].call(g, source)):
		return false
	if bool(e["spell_only"]) and not packet.source_was_spell:
		return false
	if bool(e["combat_only"]) and not packet.is_combat:
		return false
	var victim: CardInstance = null
	if packet.target.is_player:
		if not covers_player(e, packet.target.player_id):
			return false
	else:
		victim = g.find_instance(packet.target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return false
		if not covers_creature(e, victim):
			return false
	var kind := StringName(e["kind"])
	if victim != null and (kind == KIND_PREVENT or kind == KIND_REDIRECT) \
			and (victim.damage_unpreventable_this_turn or packet.unpreventable_to_creatures):
		return false   # CR 615.12; Whippoorwill forbids "dealt instead" too
	match kind:
		KIND_MODIFY:
			if _modified(amount, e) == amount:
				return false
		KIND_COUNTERS:
			if victim == null:
				return false   # a player can't be given counters this way
		KIND_REDIRECT:
			var to := destination(g, packet, e)
			if to == null or to.same_object(packet.target):
				return false   # nowhere else to go: it does not apply (CR 614.6)
	if e.has("filter") and not bool(e["filter"].call(g, packet)):
		return false
	return true


static func covers_player(e: Dictionary, pid: int) -> bool:
	var victims: Array = e["victims"]
	if victims.is_empty() and int(e["creatures_of"]) < 0:
		return true
	for v in victims:
		if (v as Dictionary).has("player") and int(v["player"]) == pid:
			return true
	return false


static func covers_creature(e: Dictionary, inst: CardInstance) -> bool:
	var victims: Array = e["victims"]
	if victims.is_empty() and int(e["creatures_of"]) < 0:
		return true
	if int(e["creatures_of"]) >= 0 and inst.controller_id == int(e["creatures_of"]) \
			and inst.is_creature():
		return true
	for v in victims:
		var d: Dictionary = v
		if d.has("id") and int(d["id"]) == inst.id \
				and (int(d.get("stamp", -1)) < 0 or int(d["stamp"]) == inst.layer_timestamp):
			return true
	return false


## Where a redirect entry sends [param packet] — a player, or a creature
## still on the battlefield as the same object — or null when there is
## nowhere to send it.
static func destination(g: MtgGame, packet: DamagePacket, e: Dictionary) -> TargetRef:
	if bool(e["to_source_controller"]):
		if packet.source == null:
			return null
		return TargetRef.player(packet.source.controller_id)
	var to: Dictionary = e.get("to", {})
	if to.has("player"):
		return TargetRef.player(int(to["player"]))
	if to.has("id"):
		var inst := g.find_instance(int(to["id"]))
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.phased_out \
				or not inst.is_creature() \
				or (int(to.get("stamp", -1)) >= 0 and inst.layer_timestamp != int(to["stamp"])):
			return null
		return TargetRef.card(inst)
	return null


## What a modifier entry turns [param amount] into.
static func _modified(amount: int, e: Dictionary) -> int:
	return maxi(amount * int(e["factor"]) + int(e["delta"]), 0)


static func _static_still_written(g: MtgGame, e: Dictionary) -> bool:
	for live in g.static_damage_effects:
		if String(live.get("static_key", "")) == String(e["static_key"]):
			return true
	return false


# ---------------------------------------------------------- applying --

## Apply the gate the affected player (or the affected creature's
## controller) picked. Returns -1 when the event carries on with whatever is
## left of [param packet], or the amount ACTUALLY dealt when the gate ended
## it — the same contract as [method MtgGame._apply_damage_gate]. A METERED
## redirect is both at once: what its split-off packet dealt is written
## back onto [param gate] under `"elsewhere"`, which the creature chain adds
## to its answer.
static func apply(g: MtgGame, packet: DamagePacket, gate: Dictionary) -> int:
	var e: Dictionary = gate["entry"]
	var source: CardInstance = packet.source
	var amount := packet.remaining()
	_spend(g, e)
	g._rec(packet, &"applied_creature_redirects")
	packet.applied_creature_redirects.append(guard_key(e))
	match StringName(e["kind"]):
		KIND_MODIFY:
			# CR 614.1a: the event deals a different AMOUNT. Not prevention —
			# the packet was only ever this big — so the change is booked on
			# `amount` itself, like a damage cap (Forethought Amulet).
			var becomes := _modified(amount, e)
			g._rec(packet, &"amount")
			packet.amount += becomes - amount
			g.log_line("%s: %s's damage to %s becomes %d" % [String(e["desc"]),
				source.data.card_name, _victim_name(g, packet), becomes])
			return 0 if packet.remaining() <= 0 else -1
		KIND_PREVENT:
			var want := amount if int(e["points"]) <= 0 \
				else mini(int(e["points_left"]), amount)
			var stopped := packet.prevent(want)
			if int(e["points"]) > 0:
				_draw_points(g, e, stopped)
			g.log_line("%s prevents %d damage from %s to %s" % [String(e["desc"]),
				stopped, source.data.card_name, _victim_name(g, packet)])
			# SIMPLIFIED (docs/ROADMAP.md, "A shield's rider runs per packet"):
			# CR 615.5 runs the rider once, after the whole prevented event;
			# this runs it per packet with that packet's amount — the same
			# total, in pieces when one event hit several victims.
			if e.has("then") and stopped > 0:
				e["then"].call(g, packet, stopped)
			return 0 if packet.remaining() <= 0 else -1
		KIND_REDIRECT:
			var to := destination(g, packet, e)
			if to == null:
				return -1
			if int(e["points"]) > 0:
				var moved := mini(int(e["points_left"]), amount)
				_draw_points(g, e, moved)
				g.log_line("%s: %d of %s's damage to %s is dealt to %s instead" % [
					String(e["desc"]), moved, source.data.card_name,
					_victim_name(g, packet), _ref_name(g, to)])
				gate["elsewhere"] = g._split_damage(packet, to, moved)
				if e.has("then"):
					e["then"].call(g, packet, moved)
				return -1
			g.log_line("%s: %s's damage to %s is dealt to %s instead" % [
				String(e["desc"]), source.data.card_name, _victim_name(g, packet),
				_ref_name(g, to)])
			if e.has("then"):
				e["then"].call(g, packet, amount)
			return g._redirect_damage(packet, to)
		KIND_COUNTERS:
			# "If damage would be dealt to this creature, put that many -1/-1
			# counters on it instead" (Lichenthrope) — a REPLACEMENT: no
			# damage is dealt, so nothing is marked, nothing hears
			# DAMAGE_DEALT, and the counters are the event instead.
			var victim := g.find_instance(packet.target.instance_id)
			g._rec(packet, &"amount")
			packet.amount -= amount
			g.log_line("%s: %s's %d damage becomes %d %s counter(s) on %s" % [
				String(e["desc"]), source.data.card_name, amount, amount,
				String(e["counter"]), victim.data.card_name])
			g.add_counters(victim, String(e["counter"]), amount)
			if e.has("then"):
				e["then"].call(g, packet, amount)
			return 0
		KIND_REPLACE:
			return int(e["apply"].call(g, packet))
	return -1


## Mark a one-shot entry spent by the event in progress (CR 615.8): it
## goes on applying to the rest of that event and is pruned when the next
## one begins ([method prune_spent]).
static func _spend(g: MtgGame, e: Dictionary) -> void:
	if not bool(e["one_shot"]) or e.has("static_key"):
		return
	if int(e["spent_event"]) == g._damage_event_serial:
		return
	g._rec(g, &"damage_effects")
	e["spent_event"] = g._damage_event_serial


static func _draw_points(g: MtgGame, e: Dictionary, used: int) -> void:
	if used <= 0 or e.has("static_key"):
		return
	g._rec(g, &"damage_effects")
	e["points_left"] = int(e["points_left"]) - used
	if int(e["points_left"]) <= 0:
		_remove_entry(g, e)


static func _remove_entry(g: MtgGame, e: Dictionary) -> void:
	for i in g.damage_effects.size():
		if is_same(g.damage_effects[i], e):
			g._rec(g, &"damage_effects")
			g.damage_effects.remove_at(i)
			return


static func _victim_name(g: MtgGame, packet: DamagePacket) -> String:
	return _ref_name(g, packet.target)


static func _ref_name(g: MtgGame, ref: TargetRef) -> String:
	if ref == null:
		return "?"
	if ref.is_player:
		return g.players[ref.player_id].player_name
	var inst := g.find_instance(ref.instance_id)
	return inst.data.card_name if inst != null else "?"


# ---------------------------------------------------------- durations --

## A new damage event has begun: drop the one-shot entries an earlier event
## used up. The caller has already journaled nothing; this records the list
## itself before it changes.
static func prune_spent(g: MtgGame) -> void:
	var keep: Array[Dictionary] = []
	var dropped := false
	for e in g.damage_effects:
		if bool(e["one_shot"]) and int(e["spent_event"]) >= 0 \
				and int(e["spent_event"]) != g._damage_event_serial:
			dropped = true
			continue
		keep.append(e)
	if dropped:
		g._rec(g, &"damage_effects")
		g.damage_effects = keep


## The cleanup step (CR 514.2): "this turn" ends. Longer durations stay.
static func expire_turn(g: MtgGame) -> void:
	_expire(g, func(e: Dictionary) -> bool: return StringName(e["lasts"]) == &"turn")


## [param pid]'s upkeep begins: "until your next upkeep" ends (CR 611.2b).
static func expire_upkeep_of(g: MtgGame, pid: int) -> void:
	_expire(g, func(e: Dictionary) -> bool:
		return StringName(e["lasts"]) == &"upkeep" and int(e["lasts_pid"]) == pid)


static func _expire(g: MtgGame, ends: Callable) -> void:
	if g.damage_effects.is_empty():
		return
	var keep: Array[Dictionary] = []
	for e in g.damage_effects:
		if not bool(ends.call(e)):
			keep.append(e)
	if keep.size() != g.damage_effects.size():
		g._rec(g, &"damage_effects")
		g.damage_effects = keep


# ------------------------------------------------- public descriptions --

## The entries that NAME player [param pid] as a victim, as portrait-badge
## lines (presentation only — no Callables or ids, see
## [method MtgGame.player_damage_effects]). A table-wide effect (Blind Fury,
## Benevolent Unicorn) is the permanent's to show, not the portrait's.
static func describe_for_player(g: MtgGame, pid: int) -> Array[String]:
	var out: Array[String] = []
	for list in [g.damage_effects, g.static_damage_effects]:
		for e in list:
			var named := false
			for v in e["victims"]:
				if (v as Dictionary).has("player") and int(v["player"]) == pid:
					named = true
			if not named:
				continue
			if bool(e["one_shot"]) and int(e["spent_event"]) >= 0:
				continue
			var line := String(e["desc"])
			if int(e["source_id"]) >= 0:
				line += " — " + g._public_damage_source_name(int(e["source_id"]))
			match StringName(e["lasts"]):
				&"upkeep": line += "; until %s's next upkeep" % g.players[maxi(int(e["lasts_pid"]), 0)].player_name
				&"indefinite": line += "; while active"
				_: line += "; while active" if e.has("static_key") else "; this turn"
			out.append(line)
	return out
