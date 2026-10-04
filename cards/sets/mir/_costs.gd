extends RefCounted
## Mirage (_costs, Pack 8). Additional and alternative costs, cumulative upkeep and cost modifiers.
##
## Every cost here is a COST (CR 118, 601.2h, 602.2b): validated before
## anything moves, chosen by the payer and paid as the spell or ability goes
## on the stack — the engine's object-cost vocabulary
## (engine/additional_object_costs.gd) and CumulativeUpkeep do the paying;
## the card only declares them. tests/cards/test_pack_8_b8_mirage.gd pins
## each card's distinguishing clause.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Prismatic Circle":
			CumulativeUpkeep.attach(c, "{1}")
			c.as_it_enters(_choose_circle_color)
			var circle := ActivatedAbility.new("{1}", false, [ChosenColorShield.new()],
				"{1}: The next time a source of your choice of the chosen color would deal damage to you this turn, prevent that damage.")
			# The colour is the one chosen as the Circle entered; it is read
			# into the activation's own record so an ability that outlives
			# its Circle still knows it (CR 608.2h).
			circle.on_cost_paid = _record_circle_color
			c.activated(circle)
		"Carrion":
			c.spell(CarrionInsects.new())
			c.with_object_cost(OC.sacrificing("a creature", _creature))
		"Phyrexian Tribute":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact)))
			c.with_object_cost(OC.sacrificing("a creature", _creature, 2))
		"Withering Boon":
			c.spell(CounterEffect.new("target creature spell", _creature_spell))
			c.with_additional_life(3)
		"Cycle of Life":
			var spec := TargetSpec.creature("target creature you cast this turn").with_source_filter(_cast_by_you)
			c.activated(ActivatedAbility.new("", false, [CycleOfLife.new(spec)],
				"Return this enchantment to its owner's hand: Target creature you cast this turn has base power and toughness 0/1 until your next upkeep. At the beginning of your next upkeep, put a +1/+1 counter on that creature.").with_return_cost())
		"Malignant Growth":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _grow,
				"At the beginning of your upkeep, put a growth counter on this enchantment.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _malignant_draw,
				"At the beginning of each opponent's draw step, that player draws an additional card for each growth counter on this enchantment, then this enchantment deals damage to the player equal to the number of cards they drew this way.",
				_opponents_draw_step))
		"Phyrexian Purge":
			# "Any number of target creatures"; every target costs 3 life
			# (CR 601.2f — a cost increase paid in life, not beyond the first).
			var purge := DestroyEffect.new(TargetSpec.creature())
			purge.target_min = 0
			purge.target_max = -1
			c.spell(purge).with_life_per_target(3)
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _creature_spell(i: CardInstance) -> bool: return i.data.is_creature()

static func _cast_by_you(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and g.cast_this_turn_by(i, s.controller_id)


# ------------------------------------------------------------ Prismatic Circle

## "As this enchantment enters, choose a color." The hint is the colour the
## opponent shows most on the battlefield (public information).
static func _choose_circle_color(g: MtgGame, s: CardInstance, pid: int) -> void:
	var counts := {}
	for i in g.players[g.opponent_of(pid)].battlefield:
		for color in Mtg.WUBRG:
			if (i.cur_colors & color) != 0: counts[color] = int(counts.get(color, 0)) + 1
	var best := Mtg.ManaColor.R
	for color in Mtg.WUBRG:
		if int(counts.get(color, 0)) > int(counts.get(best, 0)): best = color
	var picked := g.agents[pid].choose_color(g, pid, "%s: choose a color" % s.data.card_name, best)
	g._rec(s, &"memory")
	s.memory["circle_color"] = picked if Mtg.WUBRG.has(picked) else best

static func _record_circle_color(_g: MtgGame, s: CardInstance, record: Dictionary) -> void:
	record["circle_color"] = int(s.memory.get("circle_color", 0))


## The Circle of Protection shield keyed on the colour THIS Circle chose —
## the 1997 packet form and the modern "source of your choice" form alike
## (PreventDamageShieldEffect). Before a colour is chosen it stops nothing.
class ChosenColorShield extends PreventDamageShieldEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.damage("target damage from a source of the chosen color", _packet_matches)
		optional_target()

	func _packet_matches(game: MtgGame, packet: DamagePacket, who: CardInstance) -> bool:
		if packet.source == null or packet.target == null or not packet.target.is_player:
			return false
		if who != null and packet.target.player_id != who.controller_id:
			return false
		var mask := int(who.memory.get("circle_color", 0)) if who != null else 0
		return mask != 0 and (mask & game.damage_source_colors(packet.source)) != 0

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value: int = 0) -> void:
		if target != null and target.is_damage:
			super(game, source, controller, target, x_value)
			return
		var mask := int(game.cost_paid("circle_color", int(source.memory.get("circle_color", 0))))
		if mask == 0:
			return
		var choices := game.damage_sources(_of_color.bind(game, mask), TargetRef.player(controller))
		if choices.is_empty():
			game.log_line("%s: no source of the chosen color to name, nothing is shielded" % source.data.card_name)
			return
		var named := game.agents[controller].choose_card(game, controller, choices,
			"%s: Select a source of the chosen color." % source.data.card_name, false, false, true)
		if named == null or not choices.has(named):
			named = choices[0]
		game._rec(game.players[controller], &"prevention_shield_filters")
		game.players[controller].prevention_shield_filters.append({
			"desc": "%s (%s)" % [source.data.card_name, named.data.card_name],
			"chosen_source": named.id,
			"filter": PreventDamageShieldEffect._is_source.bind(named.id),
		})
		game.log_line("%s shields %s against %s this turn" % [source.data.card_name,
			game.players[controller].player_name, named.data.card_name])

	static func _of_color(inst: CardInstance, game: MtgGame, mask: int) -> bool:
		return (mask & game.damage_source_colors(inst)) != 0

	func describe() -> String:
		return "prevents the next damage from a source of the chosen color to you this turn"


# ---------------------------------------------------------------------- Carrion

## "Create X 0/1 black Insect creature tokens, where X is the sacrificed
## creature's power" — its power as it was sacrificed (the cost's receipt,
## CR 608.2h); a negative power makes none.
class CarrionInsects extends CreateTokenEffect:
	func _init() -> void:
		super("Insect", 0, 1, Mtg.ManaColor.B, "insect")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var power := 0
		for row in g.cost_paid("_object_costs", []):
			if String(row.get("operation", "")) == "sacrifice": power = int(row.get("power", 0))
		if power > 0: g.create_token(pid, token, power)
	func describe() -> String:
		return "create X 0/1 black Insect tokens, where X is the sacrificed creature's power"


# ---------------------------------------------------------------- Cycle of Life

## Base 0/1 until the activator's next upkeep (layer 7b), and a delayed
## trigger then: a +1/+1 counter on that same object (CR 400.7).
class CycleOfLife extends SetBasePowerToughnessEffect:
	func _init(spec: TargetSpec) -> void:
		super(0, 1, spec)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var inst := g.find_instance(t.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD: return
		g.continuous.add_until_eot_base_pt(inst.id, 0, 1, false, ContinuousEffects.Duration.UNTIL_UPKEEP_OF, pid)
		g.recalculate()
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
			_grow_up.bind(inst.id, inst.layer_timestamp), "Put a +1/+1 counter on that creature.",
			_upkeep_of.bind(pid)), pid, s)
	static func _upkeep_of(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool:
		return int(e.data.get("player", -1)) == pid
	static func _grow_up(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var inst := g.find_instance(id)
		if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD and inst.layer_timestamp == stamp:
			g.add_counters(inst, "+1/+1")
	func describe() -> String:
		return "target creature you cast this turn has base power and toughness 0/1 until your next upkeep, then gets a +1/+1 counter"


# ------------------------------------------------------------ Malignant Growth

static func _grow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.add_counters(s, "growth")

static func _opponents_draw_step(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) != s.controller_id

## The counters are read on resolution (last known if the Growth is gone,
## CR 608.2h); the damage is the number of cards actually drawn.
static func _malignant_draw(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var victim := int(e.data.get("player", -1))
	if victim < 0: return
	var counters := s.counters if F._same_trigger_object(g, s) else s.last_counters
	var n := int(counters.get("growth", 0))
	if n <= 0: return
	var before := g.players[victim].library.size()
	g.draw_cards(victim, n)
	var drawn := mini(n, maxi(0, before - g.players[victim].library.size()))
	if drawn > 0: g.deal_damage(s, TargetRef.player(victim), drawn)
