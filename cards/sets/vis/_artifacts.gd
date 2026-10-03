extends RefCounted
## Visions (_artifacts, Pack 8). Noncreature artifacts and their activated or static abilities.
##
## Anvil of Bogardan — "no maximum hand size" is the Library of Leng static
##   for every player; the draw-step trigger is DRAW_STEP (dispatched after
##   the step's normal draw — the trigger goes on the stack after it).
## Diamond Kaleidoscope — the Prism is a 0/1 colorless artifact creature
##   token; "Sacrifice a Prism token: Add one mana of any color" is a mana
##   ability (no stack, CR 605) with a sacrifice cost and a colour choice.
## Dragon Mask — a delayed "beginning of the next end step" trigger returns
##   the pumped creature only if it is still that object (CR 400.7).
## Juju Bubble — "When you play a card": a spell YOU cast (not a copy) or a
##   land you play.
## Magma Mine — the damage counts the pressure counters the Mine had when it
##   was sacrificed (recorded with the cost — CR 608.2h).
## Sands of Time — E8's per-recalculation skips_untap_step flag for every
##   player; the upkeep swap is one simultaneous event.
## Teferi's Puzzle Box — the player orders the cards going to the bottom
##   (each one goes beneath the last), then draws that many.
## Triangle of War — two targets; no blow is struck unless both are still
##   legal creatures (CR 701.12b) — the Arena shape (phpr/arena.gd).
## Wand of Denial — the look is private to the Wand's controller; paying the
##   2 life is optional and needs 2 life to pay (CR 119.4).
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_artifacts.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Anvil of Bogardan":
			c.static_ability(StaticAbility.new(_no_hand_limit, "Players have no maximum hand size."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _anvil,
				"At the beginning of each player's draw step, that player draws an additional card, then discards a card.",
				_any_draw_step))
		"Diamond Kaleidoscope":
			var prism := CreateTokenEffect.new("Prism", 0, 1, 0, "prism")
			prism.token.types |= Mtg.CardType.ARTIFACT
			c.activated(ActivatedAbility.new("{3}", true, [prism],
				"{3}, {T}: Create a 0/1 colorless Prism artifact creature token."))
			c.mana(ManaAbility.new(Mtg.ManaColor.W).without_tap() \
				.with_sacrifice_of("Prism token", _prism).with_color_choice(F._all_colors))
		"Dragon Mask":
			c.activated(ActivatedAbility.new("{3}", true, [MaskPump.new()],
				"{3}, {T}: Target creature you control gets +2/+2 until end of turn. Return it to its owner's hand at the beginning of the next end step."))
		"Helm of Awakening":
			c.with_cost_modifier(_helm)
		"Juju Bubble":
			CumulativeUpkeep.attach(c, "{1}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _bubble_pop,
				"When you play a card, sacrifice this artifact.", _you_played).also_when(Mtg.EventType.LAND_PLAYED))
			c.activated(ActivatedAbility.new("{2}", false, [GainLifeEffect.new(1)], "{2}: You gain 1 life."))
		"Magma Mine":
			c.activated(ActivatedAbility.new("{4}", false, [Pressure.new()],
				"{4}: Put a pressure counter on this artifact."))
			c.activated(ActivatedAbility.new("", true, [MineBlast.new()],
				"{T}, Sacrifice this artifact: It deals damage equal to the number of pressure counters on it to any target.") \
				.with_sacrifice_cost())
		"Sands of Time":
			c.static_ability(StaticAbility.new(_sands_skip, "Each player skips their untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _sands_swap,
				"At the beginning of each player's upkeep, that player simultaneously untaps each tapped artifact, creature, and land they control and taps each untapped artifact, creature, and land they control."))
		"Snake Basket":
			c.activated(ActivatedAbility.new("{X}", false, [Snakes.new()],
				"{X}, Sacrifice this artifact: Create X 1/1 green Snake creature tokens. Activate only as a sorcery.") \
				.with_sacrifice_cost().only_if(M.sorcery_speed))
		"Teferi's Puzzle Box":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _puzzle_box,
				"At the beginning of each player's draw step, that player puts the cards in their hand on the bottom of their library in any order, then draws that many cards.",
				_any_draw_step))
		"Triangle of War":
			var mine := Champion.new()
			c.activated(ActivatedAbility.new("{2}", false, [mine, Fight.new(mine.target_spec)],
				"{2}, Sacrifice this artifact: Target creature you control fights target creature an opponent controls.") \
				.with_sacrifice_cost())
		"Wand of Denial":
			c.activated(ActivatedAbility.new("", true, [Wand.new()],
				"{T}: Look at the top card of target player's library. If it's a nonland card, you may pay 2 life. If you do, put it into that player's graveyard."))
		_: return false
	return true


static func _any_draw_step(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) >= 0


# ---------------------------------------------------------- Anvil of Bogardan --

static func _no_hand_limit(g: MtgGame, _s: CardInstance) -> void:
	for p in g.players: p.max_hand_size = 999

## That player draws, then discards a card of their choice.
static func _anvil(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	g.draw_cards(who, 1)
	if g.players[who].hand.is_empty(): return
	g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))


# ------------------------------------------------------- Diamond Kaleidoscope --

static func _prism(i: CardInstance) -> bool: return i.is_token and i.has_subtype("prism")


# ----------------------------------------------------------------- Dragon Mask --

class MaskPump extends PumpEffect:
	func _init() -> void:
		super(2, 2)
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller")
	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id == g.controller_acting_for(s)
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		super(g, source, pid, t, x)
		var module: GDScript = load("res://cards/sets/vis/_artifacts.gd")
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, module._mask_return,
			"Return it to its owner's hand at the beginning of the next end step."), pid, source, false,
			{"id": i.id, "stamp": i.layer_timestamp})
	func describe() -> String:
		return "target creature you control gets +2/+2 until end of turn; return it to its owner's hand at the next end step"

static func _mask_return(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var i := g.find_instance(int(memory.get("id", -1)))
	if g.is_present(i) and i.layer_timestamp == int(memory.get("stamp", -2)):
		g.return_to_hand(i)


# ---------------------------------------------------------- Helm of Awakening --

static func _helm(_g: MtgGame, _caster: int, _data: CardData, _source: CardInstance) -> int:
	return -1


# ----------------------------------------------------------------- Juju Bubble --

static func _you_played(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var card: CardInstance = e.data.get("instance")
	return int(e.data.get("controller", -1)) == s.controller_id and card != null and not card.is_copy

static func _bubble_pop(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._trigger_source_present(g, s): g.sacrifice_permanent(s)


# ------------------------------------------------------------------ Magma Mine --

class Pressure extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if g.is_present(source) and source.layer_timestamp == int(g.cost_paid("_source_timestamp", source.layer_timestamp)):
			g.add_counters(source, "pressure")
	func describe() -> String:
		return "put a pressure counter on this artifact"

class MineBlast extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
	func resolve(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var counters: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(counters.get("pressure", 0))
		if n > 0: g.deal_damage(source, t, n)
	func describe() -> String:
		return "deals damage equal to the number of pressure counters on it to any target"


# --------------------------------------------------------------- Sands of Time --

static func _sands_skip(g: MtgGame, _s: CardInstance) -> void:
	for p in g.players: p.skips_untap_step = true

static func _sands_swap(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var to_untap: Array[CardInstance] = []
	var to_tap: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if not g.is_present(i) or not M.acl(i): continue
		if i.tapped: to_untap.append(i)
		else: to_tap.append(i)
	g.begin_simultaneous()
	for i in to_untap: g.untap_permanent(i)
	for i in to_tap: g.tap_permanent(i)
	g.end_simultaneous()


# ---------------------------------------------------------------- Snake Basket --

class Snakes extends CreateTokenEffect:
	func _init() -> void:
		super("Snake", 1, 1, Mtg.ManaColor.G, "snake")
	func resolve(g: MtgGame, _source: CardInstance, controller: int, _t: TargetRef, x := 0) -> void:
		if x > 0: g.create_token(controller, token, x)
	func describe() -> String:
		return "create X 1/1 green Snake creature tokens"


# --------------------------------------------------------- Teferi's Puzzle Box --

static func _puzzle_box(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var left: Array[CardInstance] = g.players[who].hand.duplicate()
	var n := left.size()
	if n == 0: return
	while not left.is_empty():
		var pick: CardInstance = left[0]
		if left.size() > 1 and not _all_same_name(left):
			var answer := g.agents[who].choose_card_in_order(g, who, left,
				"Teferi's Puzzle Box: put a card on the bottom of your library (each goes beneath the last)")
			if answer != null and left.has(answer): pick = answer
		left.erase(pick)
		g.put_on_bottom_of_library(pick)
	g.draw_cards(who, n)

static func _all_same_name(cards: Array[CardInstance]) -> bool:
	for i in cards:
		if i.data.card_name != cards[0].data.card_name: return false
	return true


# ------------------------------------------------------------- Triangle of War --

class Champion extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(_yours).because("controller")
	static func _yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id == g.controller_acting_for(s)
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass   # the fight is struck by the second effect, once both are known
	func describe() -> String:
		return "your creature"

class Fight extends EffectBase:
	var mine_spec: TargetSpec
	func _init(p_mine_spec: TargetSpec) -> void:
		mine_spec = p_mine_spec
		target_spec = TargetSpec.creature("target creature an opponent controls").with_source_filter(_theirs).because("controller")
	static func _theirs(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id != g.controller_acting_for(s)
	func resolve(g: MtgGame, source: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var theirs := g.find_instance(t.instance_id)
		var refs: Array = g.current_targets()
		if refs.is_empty() or not g.is_present(theirs): return
		var mine_ref: TargetRef = refs[0]
		var mine := g.find_instance(mine_ref.instance_id)
		# CR 701.12b: no damage unless both are still legal creatures.
		if not g.is_present(mine) or not mine.is_creature() or not theirs.is_creature() \
				or not mine_spec.is_legal(g, mine_ref, source):
			return
		g.begin_simultaneous()
		g.deal_damage(mine, TargetRef.card(theirs), maxi(mine.cur_power, 0))
		g.deal_damage(theirs, TargetRef.card(mine), maxi(theirs.cur_power, 0))
		g.end_simultaneous()
	func describe() -> String:
		return "your creature fights target creature an opponent controls"


# -------------------------------------------------------------- Wand of Denial --

class Wand extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, source: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var library: Array[CardInstance] = g.players[who].library
		if library.is_empty(): return
		var top: CardInstance = library.back()
		g.reveal_information(pid, "%s — top card of %s's library" % [source.data.card_name, g.players[who].player_name],
			[top.data.card_name])
		if top.data.is_land() or g.players[pid].life < 2: return
		# The seat that looked decides (it may use what it saw): deny an
		# opponent a spell while life is comfortable; keep its own.
		var hint := who != pid and g.players[pid].life > 6
		if g.agents[pid].choose_yes_no(g, pid,
				"%s: pay 2 life to put %s into %s's graveyard?" % [source.data.card_name, top.data.card_name, g.players[who].player_name], hint):
			g.adjust_life(pid, -2)
			g.put_library_card_into_graveyard(top)
	func describe() -> String:
		return "look at the top card of target player's library; if it's nonland, you may pay 2 life to mill it"
