extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Giant Oyster":
			c.with_may_skip_untap()
			c.activated(F._ability("", true, F.Action.new(_oyster, "lock target tapped creature and put a -1/-1 counter on it each of your draw steps while this creature remains tapped", TargetSpec.creature("target tapped creature", _tapped))))
		"Hazduhr the Abbot", "Daughter of Autumn":
			var x := c.card_name == "Hazduhr the Abbot"
			var effect := CreatureRedirectEffect.new(1, x)
			effect.target_spec = TargetSpec.creature("target white creature", F._color.bind(Mtg.ManaColor.W))
			if x: effect.target_spec.with_source_filter(F._own)
			c.activated(F._ability("{X}" if x else "{W}", x, effect))
		_: return false
	return true

static func _tapped(i: CardInstance) -> bool: return i.tapped
static func _live(g: MtgGame, id: int, stamp: int) -> CardInstance:
	var i := g.find_instance(id)
	# is_present: a phased-out source holds nothing ("for as long as it
	# remains tapped" sees it no more, CR 702.26f) and a phased-out
	# creature can't be redirected to or affected (702.26b).
	return i if g.is_present(i) and i.layer_timestamp == stamp else null
static func _held(g: MtgGame, s: CardInstance, stamp: int, sequence: int) -> bool:
	return _live(g, s.id, stamp) != null and s.tapped and s.untap_sequence == sequence
static func _oyster(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if not F._remained_tapped(g, s): return
	var victim := g.find_instance(t.instance_id)
	var id := victim.id
	var stamp := victim.layer_timestamp
	var source_stamp := s.layer_timestamp
	var sequence := s.untap_sequence
	g.continuous.add_floating_static(s, StaticAbility.new(_lock.bind(id, stamp, source_stamp, sequence), "Doesn't untap while the Oyster remains tapped."), ContinuousEffects.Duration.INDEFINITE, -1, false, id)
	# [forge] cardsfolder/g/giant_oyster.txt @ b09a3d3f: a separate effect
	# persists if the Oyster loses abilities. Its lifetime is broken by an
	# untap, not merely tested against the later tapped state.
	var draw := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _counter.bind(id, stamp), "Put a -1/-1 counter on the imprisoned creature.", _draw_due.bind(pid, source_stamp, sequence)), pid, s, true)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.BECAME_UNTAPPED, _release.bind(id, stamp, int(draw.id)), "Remove all -1/-1 counters from the imprisoned creature.", _released.bind(source_stamp, sequence)).also_when(Mtg.EventType.LEAVES_BATTLEFIELD), pid, s)
	g._rec(s, &"memory")
	s.memory["hml_oyster"] = [id, stamp, sequence]
	g.recalculate()
static func _lock(g: MtgGame, s: CardInstance, id: int, stamp: int, source_stamp: int, sequence: int) -> void:
	var i := _live(g, id, stamp)
	if i != null and _held(g, s, source_stamp, sequence): i.cur_skips_untap = true
static func _draw_due(g: MtgGame, s: CardInstance, e: GameEvent, pid: int, stamp: int, sequence: int) -> bool:
	return int(e.data.player) == pid and _held(g, s, stamp, sequence)
static func _counter(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := _live(g, id, stamp)
	if i != null: g.add_counters(i, "-1/-1")
static func _released(_g: MtgGame, s: CardInstance, e: GameEvent, stamp: int, sequence: int) -> bool:
	return e.data.instance == s and s.layer_timestamp == stamp and (s.zone != Mtg.Zone.BATTLEFIELD or s.untap_sequence != sequence)
static func _release(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int, draw_id: int) -> void:
	g.retire_delayed_trigger(draw_id)
	var i := _live(g, id, stamp)
	if i != null: g.remove_counters(i, "-1/-1", int(i.counters.get("-1/-1", 0)))
