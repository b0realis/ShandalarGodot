extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const T := preload("res://cards/sets/all/_triggers.gd")
const O := preload("res://cards/sets/hml/_oyster_redirect.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dystopia":
			CumulativeUpkeep.attach(c, "", 1)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _dystopia, "Active player sacrifices a green or white permanent."))
		"Nature's Wrath":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wrath_upkeep, "Sacrifice this enchantment unless you pay {G}.", F._your_upkeep))
			for color in [Mtg.ManaColor.U, Mtg.ManaColor.B]:
				c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _wrath_sacrifice.bind(color), "That player sacrifices a matching permanent.", _wrath_match.bind(color)).capturing(_entry_player))
		"Royal Decree":
			CumulativeUpkeep.attach(c, "{W}")
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _decree, "Deal 1 damage to that permanent's controller.", _decree_match).capturing(_entry_player))
		"Sustaining Spirit":
			CumulativeUpkeep.attach(c, "{1}{W}")
			c.static_ability(StaticAbility.new(_life_floor, "Damage cannot reduce your life total below 1."))
		"Storm Cauldron":
			c.static_ability(StaticAbility.new(_land_drop, "Each player may play one additional land on their turn."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _land_return, "Return that land to its owner's hand.").capturing(_tapped_land))
		"Winter's Night": c.triggered(TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _winter, "Add a mana of a type produced; the snow land skips its next untap.", _snow_land).as_mana_trigger())
		"Tidal Control":
			CumulativeUpkeep.attach(c, "{2}")
			c.activated(F._ability("{2}", false, CounterEffect.new("target red or green spell", _red_green)).anyone_activated())
			c.activated(F._ability("", false, CounterEffect.new("target red or green spell", _red_green)).with_life_cost(2).anyone_activated())
		"Thought Lash":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _lash_upkeep, "Cumulative upkeep—exile the top card. If unpaid, exile your library.", F._your_upkeep))
			c.activated(F._ability("", false, PreventDamageEffect.new(1).to_controller()).with_library_exile_cost(1))
		"Varchild's War-Riders":
			c.with_rampage(1)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _riders, "Cumulative upkeep—an opponent creates a Survivor.", F._your_upkeep))
		"Tornado":
			CumulativeUpkeep.attach(c, "{G}")
			c.activated(_tornado_ability(0))
			c.static_ability(StaticAbility.new(_velocity_price, "Pay 3 life per velocity counter to activate.").changing_abilities())
		"Omen of Fire": c.spell(F.Action.new(_omen, "return all Islands, then each player sacrifices a white permanent or Plains per white permanent they control"))
		_: return false
	return true

static func _green_white(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.G | Mtg.ManaColor.W)) != 0
static func _dystopia(g: MtgGame, _s: CardInstance, e: GameEvent) -> void: T.sacrifice(g, int(e.data.player), _green_white, "a green or white permanent")
static func _wrath_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := int(g.trigger_context(s).controller)
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{G}"), "Pay {G} for Nature's Wrath?", true) and s.controller_id == pid: g.sacrifice_permanent(s)
static func _wrath_food(i: CardInstance, color: int) -> bool: return (i.cur_colors & color) != 0 or (i.is_land() and i.has_subtype("island" if color == Mtg.ManaColor.U else "swamp"))
static func _wrath_match(_g: MtgGame, _s: CardInstance, e: GameEvent, color: int) -> bool: return _wrath_food(e.data.instance, color)
static func _entry_player(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary: return {"player": int(e.data.controller)}
static func _wrath_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent, color: int) -> void: T.sacrifice(g, int(g.trigger_context(s).player), _wrath_food.bind(color), "a blue permanent or Island" if color == Mtg.ManaColor.U else "a black permanent or Swamp")
static func _decree_match(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.instance
	return (i.cur_colors & (Mtg.ManaColor.B | Mtg.ManaColor.R)) != 0 or (i.is_land() and (i.has_subtype("swamp") or i.has_subtype("mountain")))
static func _decree(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.deal_damage(s, TargetRef.player(int(g.trigger_context(s).player)), 1)
static func _life_floor(g: MtgGame, s: CardInstance) -> void: g.players[s.controller_id].min_life_from_damage = maxi(1, g.players[s.controller_id].min_life_from_damage)
static func _land_drop(g: MtgGame, _s: CardInstance) -> void:
	for pid in 2: g.extra_land_plays[pid] = int(g.extra_land_plays.get(pid, 0)) + 1
static func _tapped_land(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary: return {"id": e.data.instance.id, "stamp": e.data.instance.layer_timestamp}
static func _land_return(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var land := O._live(g, int(ctx.id), int(ctx.stamp))
	if land != null: g.return_to_hand(land)
static func _snow_land(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool: return (e.data.instance.cur_supertypes & Mtg.Supertype.SNOW) != 0
static func _winter(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if not e.data.get("colors", []).is_empty(): preload("res://cards/sets/2ed/mana_flare.gd")._bonus_mana(g, s, e)
	g.skip_untap_during_next_step(e.data.instance, int(e.data.controller))
static func _red_green(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.R | Mtg.ManaColor.G)) != 0
static func _lash_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	# Cumulative upkeep's "if this permanent is on the battlefield" fails
	# while it is phased out (CR 702.24a, 702.26b): no payment is owed.
	if not F._same_trigger_source(g, s) or not g.is_present(s): return
	var pid := int(g.trigger_context(s).controller)
	g.add_counters(s, "age")
	var age := int(s.counters.get("age", 0))
	var pay := g.players[pid].library.size() >= age and g.agents[pid].choose_yes_no(g, pid, "Exile %d cards for Thought Lash's cumulative upkeep?" % age, g.players[pid].library.size() > age + 5)
	if pay:
		for n in age: g.exile_top_of_library(pid, false)
	else:
		if s.controller_id == pid: g.sacrifice_permanent(s)
		g.queue_reflexive_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _lash_library.bind(pid), "Exile all cards from your library."), pid, s, _e)
static func _lash_library(g: MtgGame, _s: CardInstance, _e: GameEvent, pid: int) -> void:
	while not g.players[pid].library.is_empty(): g.exile_top_of_library(pid, false)
static func _riders(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s) or not g.is_present(s): return   # CR 702.24a, 702.26b
	var pid := int(g.trigger_context(s).controller)
	g.add_counters(s, "age")
	var age := int(s.counters.get("age", 0))
	if g.agents[pid].choose_yes_no(g, pid, "Give an opponent %d Survivors for cumulative upkeep?" % age, age <= 3):
		g.create_token(1 - pid, CardData.new("Survivor", "", Mtg.CardType.CREATURE).pt(1, 1).with_colors(Mtg.ManaColor.R).with_subtypes(["survivor"]), age)
	elif s.controller_id == pid: g.sacrifice_permanent(s)
static func _tornado_ability(life: int) -> ActivatedAbility: return F._ability("{2}{G}", false, Tornado.new()).with_life_cost(life).per_turn(1)
static func _velocity_price(_g: MtgGame, s: CardInstance) -> void:
	if not s.cur_activated_abilities.is_empty(): s.cur_activated_abilities[0] = _tornado_ability(3 * int(s.counters.get("velocity", 0)))
class Tornado extends DestroyEffect:
	func _init() -> void: super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		if B.live_source(g, s): g.add_counters(s, "velocity")
static func _plains_white(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.W) != 0 or (i.is_land() and i.has_subtype("plains"))
static func _omen(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	g.begin_simultaneous()
	for i in g.all_battlefield().duplicate():
		if i.is_land() and i.has_subtype("island"): g.return_to_hand(i)
	g.end_simultaneous()
	# APNAP chooses using the post-return battlefield.
	for pid in [g.active_player, 1 - g.active_player]:
		var count := 0
		for i in g.players[pid].battlefield:
			if (i.cur_colors & Mtg.ManaColor.W) != 0: count += 1
		T.sacrifice(g, pid, _plains_white, "a Plains or white permanent", count)
