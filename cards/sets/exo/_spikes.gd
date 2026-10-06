extends RefCounted
## Exodus (_spikes, Pack 9). Spikes: creatures that enter with +1/+1
## counters and move them to other creatures.
##
## The shared shape is cards/sets/tmp/_spikes.gd (P).
##
## - Spike Cannibal: "move all +1/+1 counters from all creatures onto it"
##   takes every +1/+1 counter off every OTHER creature on the battlefield,
##   both players', and puts that many on the Cannibal. A move that cannot
##   put the counter onto the second object moves nothing (CR 122.5): if
##   the Cannibal has left the battlefield (or left and come back, a new
##   object — CR 400.7) by the time the trigger resolves, no counter is
##   removed from anything. Spikes stripped to 0/0 die to the state-based
##   action afterwards.
## - Spike Hatcher's regeneration and Spike Weaver's Fog carry their
##   effects' own 1997-window flags (EffectBase.is_regeneration /
##   is_damage_prevention), so both can be used in the damage-prevention
##   and regeneration windows of the 1997 rules.
## - Spike Rogue's second ability pays "Remove a +1/+1 counter from a
##   creature you control" with Pack 9 E7's object cost
##   (additional_object_costs.gd `removing_counter`): the payer chooses one
##   of their creatures that carries a +1/+1 counter — the Rogue itself
##   included — and the counter comes off at activation.
const F := preload("res://cards/sets/fem/_rules.gd")
const P := preload("res://cards/sets/tmp/_spikes.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Spike Cannibal":
			c.with_enters_counters("+1/+1", 1)
			var feast := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _cannibal,
				"When this creature enters, move all +1/+1 counters from all creatures onto it.", F._self_enter)
			# The fair AI's shape (the Pack 9 bug pass, h6-7;
			# engine/ai/tempest_spells.gd `cannibal_choice`): every other
			# creature's counters of this kind, both players', come here.
			feast.set_meta(&"ai_role", &"take_all_counters")
			feast.set_meta(&"ai_parameters", {"kind": "+1/+1"})
			c.triggered(feast)
		"Spike Hatcher":
			c.with_enters_counters("+1/+1", 6)
			c.activated(P.move_ability())
			c.activated(P.counter_ability("{1}", RegenerateEffect.new(),
				"{1}, Remove a +1/+1 counter from this creature: Regenerate this creature."))
		"Spike Rogue":
			c.with_enters_counters("+1/+1", 2)
			c.activated(P.move_ability())
			c.activated(ActivatedAbility.new("{2}", false,
				[F.Action.new(_counter_on_self, "put a +1/+1 counter on this creature", null, true)],
				"{2}, Remove a +1/+1 counter from a creature you control: Put a +1/+1 counter on this creature.") \
				.with_object_cost(OC.removing_counter("+1/+1", "creature you control", _creature)))
		"Spike Weaver":
			c.with_enters_counters("+1/+1", 3)
			c.activated(P.move_ability())
			c.activated(P.counter_ability("{1}", PreventCombatDamageEffect.new(),
				"{1}, Remove a +1/+1 counter from this creature: Prevent all combat damage that would be dealt this turn."))
		_: return false
	return true


static func _creature(inst: CardInstance) -> bool:
	return inst.is_creature()


# ------------------------------------------------------------- Spike Cannibal --

static func _cannibal(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return   # CR 122.5: nowhere to move them, so nothing moves
	# Every counter moves at once (CR 122.5, 608.2): counted first and put
	# on the Cannibal, then taken off the donors, so a donor that a
	# state-based action of this resolution kills before its own removal
	# has still given what it carried.
	var donors: Array[CardInstance] = []
	var counts: Array[int] = []
	var total := 0
	for inst in g.all_battlefield():
		if inst == s or inst.phased_out or not inst.is_creature():
			continue
		var n := int(inst.counters.get("+1/+1", 0))
		if n > 0:
			donors.append(inst)
			counts.append(n)
			total += n
	if total == 0:
		return
	g.add_counters(s, "+1/+1", total)
	for i in donors.size():
		g.remove_counters(donors[i], "+1/+1", counts[i])


# ---------------------------------------------------------------- Spike Rogue --

## "Put a +1/+1 counter on this creature" — the Rogue that activated it,
## only while it is still that object (CR 400.7).
static func _counter_on_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.add_counters(s, "+1/+1", 1)
