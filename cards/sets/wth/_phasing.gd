extends RefCounted
## Weatherlight (_phasing, Pack 8). Phasing and the cards that phase permanents in and out.
##
## Same conventions as the Mirage module (cards/sets/mir/_phasing.gd, whose
## helper class H and effect classes this one shares).
const F := preload("res://cards/sets/fem/_rules.gd")
const PH := preload("res://cards/sets/mir/_phasing.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Tolarian Drake":
			PH.H.phasing(c)
		"Vodalian Illusionist":
			c.activated(ActivatedAbility.new("{U}{U}", true, [PH.PhaseOutTarget.new(TargetSpec.creature())],
				"{U}{U}, {T}: Target creature phases out."))
		"Ertai's Familiar":
			PH.H.phasing(c)
			# One ability, two events: the phasing-out permanent hears its
			# own PHASED_OUT (CR 603.10a looks back), and a dying one its
			# own LEAVES_BATTLEFIELD.
			c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_OUT, _familiar_mill,
				"When this creature phases out or leaves the battlefield, mill three cards.", PH.H.is_self)
				.also_when(Mtg.EventType.LEAVES_BATTLEFIELD))
			c.activated(ActivatedAbility.new("{U}", false, [F.Action.new(_familiar_anchor,
				"until your next upkeep, this creature can't phase out", null, true)],
				"{U}: Until your next upkeep, this creature can't phase out."))
		"Teferi's Veil":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _veil,
				"Whenever a creature you control attacks, it phases out at end of combat.",
				_own_attackers).capturing(_attackers_context))
		_:
			return false
	return true


# ---------------------------------------------------------- Ertai's Familiar

static func _familiar_mill(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.mill(PH.H.trigger_pid(g, s), 3)


## "Until your next upkeep" — "your" is the activator's (CR 109.5). A
## Familiar that left and came back is a new object the ability never named.
static func _familiar_anchor(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if PH.H.same_activation_source(g, s): g.forbid_phasing_out(s, pid, s)


# ------------------------------------------------------------- Teferi's Veil

static func _own_attackers(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	for a in e.data.get("attackers", []):
		if a != null and a.controller_id == s.controller_id: return true
	return false


## Each attacking creature this Veil's controller controlled as they were
## declared, by id and timestamp (CR 400.7).
static func _attackers_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ids: Array = []
	for a in e.data.get("attackers", []):
		if a != null and a.controller_id == s.controller_id: ids.append([a.id, a.layer_timestamp])
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id, "attackers": ids}


## The engine announces the whole declaration as one event, so this is one
## trigger for every attacker of ours rather than one per creature — which
## changes nothing observable: each creature still gets its own delayed
## "phases out at end of combat" (CR 603.7), holding even if it has left
## combat by then, and nothing in the pool counts or orders the triggers.
## A real delayed TRIGGER, controlled by the Veil trigger's controller (CR
## 603.7d): at end of combat it goes on the stack with that step's other
## triggers in APNAP order (CR 603.3b), so the defending player's own "at
## end of combat" triggers (Heat Stroke, Sawtooth Ogre) resolve first.
## It lasts this turn only (its combat's end comes this turn).
static func _veil(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(s)
	var pid := int(context.get("controller", s.controller_id))
	for row in context.get("attackers", []):
		var trigger := TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
			_veil_fade.bind(int(row[0]), int(row[1])),
			"At end of combat, that creature phases out.")
		var entry := g.schedule_delayed_trigger(trigger, pid, s)
		entry["expires_turn"] = g.turn_number


static func _veil_fade(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if g.is_present(i) and i.layer_timestamp == stamp: g.phase_out(i)
