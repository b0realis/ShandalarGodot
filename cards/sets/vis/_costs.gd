extends RefCounted
## Visions (_costs, Pack 8). Additional and alternative costs, cumulative upkeep and cost modifiers.
##
## The costs are the engine's own vocabulary (engine/additional_object_costs.gd,
## ActivatedAbility.with_return_cost, CardData.with_alternative_cost,
## CumulativeUpkeep): validated before anything moves, chosen by the payer,
## paid as the spell or ability goes on the stack (CR 601.2h, 602.2b).
## tests/cards/test_pack_8_b8_visions.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Gossamer Chains":
			var spec := TargetSpec.creature("target unblocked creature").with_game_filter(_unblocked)
			c.activated(ActivatedAbility.new("", false, [PreventCombatDamageEffect.new().by_target_creature(spec)],
				"Return this enchantment to its owner's hand: Prevent all combat damage that would be dealt by target unblocked creature this turn.").with_return_cost())
		"Flooded Shoreline":
			c.activated(ActivatedAbility.new("{U}{U}", false, [ReturnToHandEffect.new(TargetSpec.creature())],
				"{U}{U}, Return two Islands you control to their owner's hand: Return target creature to its owner's hand.")
				.with_object_cost(OC.returning("an Island you control", _island, 2)))
		"Ovinomancer":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _ovinomancer_enters,
				"When this creature enters, sacrifice it unless you return three basic lands you control to their owner's hand.", F._self_enter))
			c.activated(ActivatedAbility.new("", true, [Sheepify.new()],
				"{T}, Return this creature to its owner's hand: Destroy target creature. It can't be regenerated. That creature's controller creates a 0/1 green Sheep creature token.").with_return_cost())
		"Infernal Harvest":
			c.spell(Harvest.new())
			c.with_object_cost(OC.times_x(OC.returning("a Swamp you control", _swamp)))
		"Kaervek's Spite":
			c.spell(GainLifeEffect.new(-5).target_player())
			c.with_object_cost(OC.sacrifice_all()).with_object_cost(OC.discard_hand())
		"Wicked Reward":
			c.spell(PumpEffect.new(4, 2))
			c.with_object_cost(OC.sacrificing("a creature", _creature))
		"Fireblast":
			c.spell(DamageEffect.new(4).any_target())
			c.with_alternative_cost("Sacrifice two Mountains",
				{"object_costs": [OC.sacrificing("a Mountain", _mountain, 2)]})
			c.with_ai_mode(_fireblast_mode)
		"Quirion Ranger":
			c.activated(ActivatedAbility.new("", false, [UntapEffect.new(TargetSpec.creature())],
				"Return a Forest you control to its owner's hand: Untap target creature. Activate only once each turn.")
				.with_object_cost(OC.returning("a Forest you control", _forest)).per_turn(1))
		"Corrosion":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _corrode,
				"At the beginning of your upkeep, put a rust counter on each artifact target opponent controls. Then destroy each artifact with mana value less than or equal to the number of rust counters on it. Artifacts destroyed this way can't be regenerated.",
				F._your_upkeep).targeting(TargetSpec.opponent()))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _derust,
				"When this enchantment leaves the battlefield, remove all rust counters from all permanents.", F._self_enter))
		"Firestorm Hellkite":
			CumulativeUpkeep.attach(c, "{U}{R}")
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _island(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("island")
static func _swamp(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("swamp")
static func _forest(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("forest")
static func _mountain(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("mountain")
static func _basic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0

## "Unblocked" exists only once blockers are declared (CR 509.1h, 506.4):
## an attacking creature whose band no creature blocked.
static func _unblocked(g: MtgGame, i: CardInstance) -> bool:
	if not g.combat.attackers.has(i.id) or g.awaiting_blockers: return false
	if not g.current_step() in [Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.FIRST_STRIKE_DAMAGE,
			Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]:
		return false
	return not g.combat.was_blocked(g.combat.band_of(i.id))


# ------------------------------------------------------------------ Ovinomancer

## "Sacrifice it unless you return three basic lands you control" — a
## payment made while the trigger resolves (MtgGame.unless_objects_paid).
## The default answer keeps the Wizard when the lands can be spared.
static func _ovinomancer_enters(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := int(g.trigger_context(s).get("controller", s.controller_id))
	if s.controller_id != pid: return
	var lands := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): lands += 1
	if g.unless_objects_paid(pid, s, [OC.returning("a basic land you control", _basic_land, 3)],
			"Ovinomancer: return three basic lands you control to their owner's hand? (otherwise sacrifice it)", lands >= 5):
		return
	g.sacrifice_permanent(s)


## Destroy target creature, no regeneration; its controller (last known,
## CR 608.2h) creates the Sheep whether or not it died — a separate
## instruction.
class Sheepify extends DestroyEffect:
	var sheep: CardData
	func _init() -> void:
		super(TargetSpec.creature(), false)
		sheep = CardData.new("Sheep", "", Mtg.CardType.CREATURE).pt(0, 1) \
			.with_colors(Mtg.ManaColor.G).with_subtypes(["sheep"])
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD: return
		var who := victim.controller_id
		g.destroy(victim, false)
		g.create_token(who, sheep)
	func describe() -> String:
		return "destroy target creature (it can't be regenerated); its controller creates a 0/1 green Sheep token"


# -------------------------------------------------------------- Infernal Harvest

## "X damage divided as you choose among any number of target creatures":
## X = 0 may name no target at all.
class Harvest extends DamageEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.creature()
		divided(-1)
		target_min = 0
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if t == null: return
		super(g, s, pid, t, x)
	func resolve_multi(g: MtgGame, s: CardInstance, pid: int, targets: Array, x := 0) -> void:
		if targets.is_empty(): return
		super(g, s, pid, targets, x)
	func describe() -> String:
		return "deals X damage divided as you choose among any number of target creatures"


# --------------------------------------------------------------------- Fireblast

## The AI's payment row (public state only): the printed {4}{R}{R} whenever
## it can be paid; the two Mountains only when the mana is short AND the
## four damage matters — the opponent is in range, or a real threat dies.
static func _fireblast_mode(g: MtgGame, pid: int) -> int:
	var mountains := 0
	for i in g.players[pid].battlefield:
		if _mountain(i): mountains += 1
	if mountains < 2: return 0
	if g.can_afford_cost(pid, ManaCost.parse("{4}{R}{R}"), [], pid): return 0
	var opponent := g.opponent_of(pid)
	if g.players[opponent].life <= 4: return 1
	for i in g.players[opponent].battlefield:
		if i.is_creature() and not i.cur_indestructible and i.cur_power >= 3 \
				and i.cur_toughness - i.damage <= 4:
			return 1
	return 0


# ---------------------------------------------------------------------- Corrosion

static func _corrode(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ref := g.current_trigger_target(0)
	if ref != null and ref.is_player:
		for i in g.players[ref.player_id].battlefield.duplicate():
			if i.is_type(Mtg.CardType.ARTIFACT): g.add_counters(i, "rust")
	# "Then destroy each artifact" — every artifact on the battlefield,
	# whoever controls it, whose mana value is at most its rust counters
	# (a mana value 0 artifact qualifies with none), all at once.
	var doomed: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_type(Mtg.CardType.ARTIFACT) and _mana_value(i) <= int(i.counters.get("rust", 0)):
			doomed.append(i)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed: g.destroy(i, false)
	g.end_simultaneous()
	g.log_line("%s corrodes %d artifact(s)" % [s.data.card_name, doomed.size()])

static func _mana_value(i: CardInstance) -> int:
	return 0 if i.face_down else i.data.cost.mana_value()

static func _derust(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		var n := int(i.counters.get("rust", 0))
		if n > 0: g.remove_counters(i, "rust", n)
