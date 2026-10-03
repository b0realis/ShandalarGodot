extends RefCounted
## Mirage (_phasing, Pack 8). Phasing and the cards that phase permanents in and out.
##
## Built on engine package E1 (MtgGame "phasing" section, CR 702.26):
## - PHASING the keyword, printed ([code]H.phasing[/code]) or granted by a layer-6
##   static (Cloak of Invisibility, Teferi's Curse, Shimmer). The untap-step
##   action itself is the engine's (CR 502.1) — nothing here runs it.
## - one-shot "phases out" through MtgGame.phase_out (it comes back at its
##   controller's next untap step by itself), batches through
##   MtgGame.phase_simultaneously (Taniwha's lands, Dream Fighter's pair),
##   and the PHASED_OUT / PHASED_IN events (Teferi's Imp, Warping Wurm).
## - "can't phase out" through MtgGame.forbid_phasing_out (Spatial Binding).
## A remembered permanent's liveness is MtgGame.is_present — a phased-out
## permanent keeps `zone == BATTLEFIELD` but does not exist (702.26b).
##
## The Visions and Weatherlight modules (cards/sets/vis/_phasing.gd,
## cards/sets/wth/_phasing.gd) reuse the helper class H and the effect
## classes (PhaseOutTarget, PhaseOutSelf) below. The phase-out effects carry
## an ai_role (&"phase_out", &"phase_out_self") for the AI to read; until it
## does they are unknown effects to it.
const F := preload("res://cards/sets/fem/_rules.gd")

## Every land type a permanent of this game can have (CR 205.3i, as far as
## the pool prints them): the five basic types, Arabian Nights' Desert and
## Antiquities' Urza's lands. Shimmer and Vision Charm name one of these.
const LAND_TYPES: Array[String] = ["plains", "island", "swamp", "mountain", "forest",
	"desert", "urza's", "mine", "power-plant", "tower"]
const LAND_LABELS: Array[String] = ["Plains", "Island", "Swamp", "Mountain", "Forest",
	"Desert", "Urza's", "Mine", "Power-Plant", "Tower"]


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Merfolk Raiders", "Sandbar Crocodile", "Teferi's Drake":
			H.phasing(c)
		"Teferi's Isle":
			H.phasing(c)
			c.with_enters_tapped()
			c.mana(ManaAbility.new(Mtg.ManaColor.U, 2))
		"Cloak of Invisibility":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(H.grant_phasing_to_host,
				"Enchanted creature has phasing.").changing_abilities())
			c.static_ability(StaticAbility.new(_walls_only,
				"Enchanted creature can't be blocked except by Walls."))
		"Teferi's Curse":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact or creature",
				_artifact_or_creature))
			c.static_ability(StaticAbility.new(H.grant_phasing_to_host,
				"Enchanted permanent has phasing.").changing_abilities())
		"Shimmer":
			c.as_it_enters(_choose_shimmer_type)
			c.static_ability(StaticAbility.new(_shimmer,
				"Each land of the chosen type has phasing.").changing_abilities())
		"Dream Fighter":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _dream_fight,
				"Whenever this creature blocks or becomes blocked by a creature, this creature and that creature phase out.",
				_in_block_pair).capturing(_pair_context))
		"Mist Dragon":
			c.activated(ActivatedAbility.new("{0}", false, [GainFlyingForever.new()],
				"{0}: This creature gains flying. (This effect lasts indefinitely.)"))
			c.activated(ActivatedAbility.new("{0}", false, [F.Action.new(_lose_flying,
				"this creature loses flying (indefinitely)")],
				"{0}: This creature loses flying. (This effect lasts indefinitely.)"))
			c.activated(ActivatedAbility.new("{3}{U}{U}", false, [PhaseOutSelf.new()],
				"{3}{U}{U}: This creature phases out."))
		"Reality Ripple":
			c.spell(PhaseOutTarget.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact, creature, or land", _artifact_creature_or_land)))
		"Sapphire Charm":
			c.mode("Target player draws a card at the beginning of the next turn's upkeep",
				[TargetDelayedDraw.new()])
			c.mode("Target creature gains flying until end of turn",
				[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])])
			c.mode("Target creature an opponent controls phases out",
				[PhaseOutTarget.new(TargetSpec.creature("target creature an opponent controls")
					.with_source_filter(H.theirs).because(TargetSpec.WHY["controller"]))])
			c.with_ai_mode(_sapphire_mode)
		"Taniwha":
			H.phasing(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _taniwha,
				"At the beginning of your upkeep, all lands you control phase out.", F._your_upkeep))
		"Teferi's Imp":
			H.phasing(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_OUT, _imp_discard,
				"Whenever this creature phases out, discard a card.", H.is_self))
			c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN, _imp_draw,
				"Whenever this creature phases in, draw a card.", H.is_self))
		"Vaporous Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, H.phase_unless_paid.bind("{U}{U}"),
				"At the beginning of your upkeep, this creature phases out unless you pay {U}{U}.", F._your_upkeep))
		"Warping Wurm":
			H.phasing(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, H.phase_unless_paid.bind("{2}{G}{U}"),
				"At the beginning of your upkeep, this creature phases out unless you pay {2}{G}{U}.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN, _wurm_counter,
				"Whenever this creature phases in, put a +1/+1 counter on it.", H.is_self))
		"Frenetic Efreet":
			c.activated(ActivatedAbility.new("{0}", false, [F.Action.new(_frenetic,
				"flip a coin; win: this creature phases out; lose: sacrifice it")],
				"{0}: Flip a coin. If you win the flip, this creature phases out. If you lose the flip, sacrifice this creature."))
		"Spatial Binding":
			c.activated(ActivatedAbility.new("", false, [F.Action.new(_bind,
				"until your next upkeep, target permanent can't phase out",
				TargetSpec.new(TargetSpec.Kind.PERMANENT), true)],
				"Pay 1 life: Until your next upkeep, target permanent can't phase out.").with_life_cost(1))
		"Crystal Golem":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _golem_fade,
				"At the beginning of your end step, this creature phases out.", F._your_upkeep))   # {player} == controller
		_:
			return false
	return true


# ================================================================ shared

## Helpers shared by the three _phasing modules (and the effect classes
## below, which reach them as H.<name>).
class H:
	## Add the PHASING keyword (the generated scaffolds predate it).
	static func phasing(c: CardData) -> void:
		if not c.keywords.has(Mtg.Keyword.PHASING):
			c.with_keywords([Mtg.Keyword.PHASING])

	## A trigger condition: the event names this very permanent.
	static func is_self(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
		return event.data.get("instance") == source

	## The source of the resolving TRIGGER is still the object that triggered
	## (present — phased in — with the same timestamp, CR 400.7 / 702.26b).
	static func same_trigger_source(g: MtgGame, source: CardInstance) -> bool:
		return g.is_present(source) \
			and source.layer_timestamp == int(g.trigger_context(source).get("timestamp", source.layer_timestamp))

	## The source of the resolving ACTIVATED ability is still the object whose
	## ability it was.
	static func same_activation_source(g: MtgGame, source: CardInstance) -> bool:
		return g.is_present(source) \
			and source.layer_timestamp == int(g.cost_paid("_source_timestamp", source.layer_timestamp))

	## The seat a resolving trigger acts for ("you"): the trigger's controller
	## — the permanent's controller as it triggered, or its last controller
	## when it triggered on leaving (CR 603.3a; a stolen Ertai's Familiar
	## mills its thief).
	static func trigger_pid(g: MtgGame, source: CardInstance) -> int:
		var pid := g.current_resolution_controller()
		if pid >= 0: return pid
		return int(g.trigger_context(source).get("controller", source.controller_id))

	## "Enchanted creature/permanent has phasing" — a layer-6 grant. Several
	## instances are redundant (CR 702.26p).
	static func grant_phasing_to_host(g: MtgGame, source: CardInstance) -> void:
		var host := g.find_instance(source.attached_to)
		if g.is_present(host) and not host.cur_keywords.has(Mtg.Keyword.PHASING):
			host.cur_keywords.append(Mtg.Keyword.PHASING)

	## "You control" / "an opponent controls" for a target: the controller of
	## the spell or ability doing the targeting (CR 109.5).
	static func theirs(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s == null or i.controller_id != g.controller_acting_for(s)

	## "At the beginning of your upkeep, this creature phases out unless you pay
	## [cost]" (Vaporous Djinn, Warping Wurm). The payer is the trigger's
	## controller; a source that has left — or already phased out — is not
	## "this creature" any more and nothing is asked.
	static func phase_unless_paid(g: MtgGame, s: CardInstance, _e: GameEvent, cost: String) -> void:
		if not same_trigger_source(g, s): return
		var pid := trigger_pid(g, s)
		if EffectBase.unless_paid(g, pid, ManaCost.parse(cost),
				"Pay %s to keep %s from phasing out?" % [cost, s.data.card_name], true):
			return
		g.phase_out(s)

	## A permanent's worth to its controller as an AI hint — public facts only.
	static func board_value(i: CardInstance) -> float:
		if i.is_creature(): return 1.0 + float(maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0))
		if i.is_land(): return 2.0
		return 1.5 + float(i.data.cost.mana_value())

	## [param list] sorted best first by [method board_value].
	static func best_first(list: Array) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for i in list: out.append(i)
		out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return board_value(a) > board_value(b))
		return out


## "Target <thing> phases out" (Reality Ripple, the charms, Vodalian
## Illusionist). A one-shot: it phases back in before its controller
## untaps during their next untap step (the engine's untap-step action).
class PhaseOutTarget extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		with_ai_role(&"phase_out")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or t.is_player: return
		g.phase_out(g.find_instance(t.instance_id))
	func describe() -> String:
		return "%s phases out" % target_spec.description


## "This creature phases out" — an activated ability of the permanent
## itself (Mist Dragon, Rainbow Efreet, Teferi's Honor Guard). A source
## that left and came back is a new object the ability never named.
class PhaseOutSelf extends EffectBase:
	func _init() -> void:
		ai_helpful = true
		with_ai_role(&"phase_out_self")
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if H.same_activation_source(g, s): g.phase_out(s)
	func describe() -> String:
		return "this creature phases out"


## Sapphire Charm's first mode: "Target player draws a card at the
## beginning of the next turn's upkeep" — Ice Age's slow cantrip
## (DelayedDrawEffect) with its recipient a target.
class TargetDelayedDraw extends DelayedDrawEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		if t == null or not t.is_player: return
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
			DelayedDrawEffect._draw, describe(), DelayedDrawEffect._next_turn.bind(g.turn_number)),
			pid, s, false, {"recipient": t.player_id, "count": amount})
	func describe() -> String:
		return "target player draws a card at the beginning of the next turn's upkeep"


## Mist Dragon's "{0}: This creature gains flying. (This effect lasts
## indefinitely.)" — a TIMESTAMPED layer-6 grant with no duration, so it
## and the "loses flying" twin below apply in the order they resolved
## (CR 613.7: the later one wins).
class GainFlyingForever extends PumpEffect:
	func _init() -> void:
		super(0, 0, [Mtg.Keyword.FLYING])
		self_buff()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if not H.same_activation_source(g, s): return
		g.continuous.add_until_eot_pump(s.id, 0, 0, [Mtg.Keyword.FLYING], false,
			ContinuousEffects.Duration.INDEFINITE)
		g.recalculate()
	func describe() -> String:
		return "this creature gains flying (indefinitely)"


# ================================================================ cards

static func _artifact_or_creature(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature()


static func _artifact_creature_or_land(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()


static func _only_walls(blocker: CardInstance) -> bool:
	return blocker.has_subtype("wall")


## Cloak of Invisibility's second half — Invisibility's block restriction.
static func _walls_only(g: MtgGame, source: CardInstance) -> void:
	var host := g.find_instance(source.attached_to)
	if g.is_present(host):
		host.cur_block_restrictions.append({"desc": "Walls", "filter": _only_walls})


# ---------------------------------------------------------------- Shimmer

## "As this enchantment enters, choose a land type" (a replacement, CR
## 614.1c). The hint names the type the opponent fields most of and its
## controller least — public battlefield counts only.
static func _choose_shimmer_type(g: MtgGame, s: CardInstance, pid: int) -> void:
	var best := 0
	var best_score := -1000
	for k in LAND_TYPES.size():
		var score := 0
		for i in g.all_battlefield():
			if i.is_land() and i.has_subtype(LAND_TYPES[k]):
				score += 1 if i.controller_id != pid else -1
		if score > best_score:
			best = k
			best_score = score
	var pick := g.agents[pid].choose_option(g, pid, LAND_LABELS, "Shimmer: choose a land type", best)
	if pick < 0 or pick >= LAND_TYPES.size(): pick = best
	g._rec(s, &"memory")
	s.memory["land_type"] = LAND_TYPES[pick]
	g.log_line("%s chooses %s for Shimmer" % [g.players[pid].player_name, LAND_LABELS[pick]])


static func _shimmer(g: MtgGame, s: CardInstance) -> void:
	var kind := String(s.memory.get("land_type", ""))
	if kind == "": return
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype(kind) and not i.cur_keywords.has(Mtg.Keyword.PHASING):
			i.cur_keywords.append(Mtg.Keyword.PHASING)


# ----------------------------------------------------------- Dream Fighter

static func _other_in_pair(source: CardInstance, event: GameEvent) -> CardInstance:
	var attacker: CardInstance = event.data.get("attacker")
	var blocker: CardInstance = event.data.get("blocker")
	if attacker == source: return blocker
	if blocker == source: return attacker
	return null


static func _in_block_pair(_g: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var other := _other_in_pair(source, event)
	return other != null and other.is_creature()


## Per occurrence: this creature's timestamp and controller, and "that
## creature" as it was when the block happened (CR 603.7c / 400.7).
static func _pair_context(_g: MtgGame, source: CardInstance, event: GameEvent) -> Dictionary:
	var other := _other_in_pair(source, event)
	return {"timestamp": source.layer_timestamp, "controller": source.controller_id,
		"other": other.id if other != null else -1,
		"other_stamp": other.layer_timestamp if other != null else -1}


static func _dream_fight(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(s)
	var outs: Array = []
	if H.same_trigger_source(g, s): outs.append(s)
	var other := g.find_instance(int(context.get("other", -1)))
	if g.is_present(other) and other.layer_timestamp == int(context.get("other_stamp", -2)):
		outs.append(other)
	g.phase_simultaneously(outs, [])


# -------------------------------------------------------------- Mist Dragon

static func _lose_flying(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not H.same_activation_source(g, s): return
	g.continuous.add_floating_static(s, StaticAbility.new(_grounded,
		"This creature loses flying.").changing_abilities(),
		ContinuousEffects.Duration.INDEFINITE, -1, false, s.id)
	g.recalculate()


static func _grounded(_g: MtgGame, s: CardInstance) -> void:
	while s.cur_keywords.has(Mtg.Keyword.FLYING):
		s.cur_keywords.erase(Mtg.Keyword.FLYING)


# ---------------------------------------------------------- Sapphire Charm

static func _sapphire_mode(g: MtgGame, pid: int) -> int:
	var best := 0.0
	for i in g.players[g.opponent_of(pid)].creatures():
		best = maxf(best, H.board_value(i))
	if best >= 5.0: return 2
	return 0


# ----------------------------------------------------------------- Taniwha

static func _taniwha(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := H.trigger_pid(g, s)
	var lands: Array = []
	for i in g.players[pid].battlefield:
		if i.is_land(): lands.append(i)
	g.phase_simultaneously(lands, [])


# ------------------------------------------------------------ Teferi's Imp

static func _imp_discard(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := H.trigger_pid(g, s)
	if g.players[pid].hand.is_empty(): return
	g.discard_cards(pid, g.agents[pid].choose_discard(g, pid, 1))


static func _imp_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(H.trigger_pid(g, s), 1)


# ------------------------------------------------------------ Warping Wurm

## The phase-in counter. The Wurm phases in during the untap step, so this
## trigger and its "phases out unless you pay" upkeep trigger go on the
## stack together, in the order its controller chooses (CR 503.1a, 603.3b —
## MtgGame._flush_upkeep_batch); put the counter first and it is on the
## Wurm before the upkeep payment is asked. Resolved after an unpaid upkeep
## instead, the Wurm is phased out and the counter has nothing to go on.
static func _wurm_counter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not H.same_trigger_source(g, s): return
	g.add_counters(s, "+1/+1", 1)


# ---------------------------------------------------------- Frenetic Efreet

## The flip happens even when the Efreet has gone (the ability resolves on
## its own, CR 608.2h); either result then acts only on the same object.
static func _frenetic(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var won := g.flip_coin(pid)
	if not H.same_activation_source(g, s): return
	if won: g.phase_out(s)
	else: g.sacrifice_permanent(s)


# --------------------------------------------------------- Spatial Binding

static func _bind(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if t == null or t.is_player: return
	var target := g.find_instance(t.instance_id)
	if g.is_present(target): g.forbid_phasing_out(target, pid, s)


# ------------------------------------------------------------ Crystal Golem

static func _golem_fade(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if H.same_trigger_source(g, s): g.phase_out(s)
