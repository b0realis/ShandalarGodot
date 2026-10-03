extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Force of Will": c.spell(CounterEffect.new()).with_pitch_cost(Mtg.ManaColor.U, 1)
		"Pyrokinesis": c.spell(DamageEffect.new(4).target_creature().divided(4)).with_pitch_cost(Mtg.ManaColor.R)
		"Contagion": c.spell(DividedCounters.new("-2/-1", 2)).with_pitch_cost(Mtg.ManaColor.B, 1)
		"Bounty of the Hunt": c.spell(DividedCounters.new("+1/+1", 3, true)).with_pitch_cost(Mtg.ManaColor.G)
		"Arcane Denial": c.spell(Denial.new())
		"Burnout": c.spell(Burnout.new()).spell(DelayedDrawEffect.new())
		"Exile": c.spell(ExileAttacker.new())
		"Energy Arc":
			var effect := F.Action.new(_arc, "untap any number of target creatures and prevent their combat damage both ways this turn", TargetSpec.creature(), true).as_damage_prevention()
			effect.target_min = 0
			effect.target_max = -1
			effect.resolves_untargeted = true
			c.spell(effect)
		"Hail Storm": c.spell(F.Action.new(_hail, "deal 2 damage to each attacking creature and 1 to you and each creature you control"))
		"Gorilla War Cry":
			c.castable_only_when(_war_cry_window)
			c.spell(F.Action.new(_war_cry, "creatures gain menace until end of turn", null, true)).spell(DelayedDrawEffect.new())
		"Lat-Nam's Legacy": c.spell(F.Action.new(_legacy, "shuffle a card from your hand into your library; if you do, draw two next turn's upkeep", null, true))
		"Foresight": c.spell(F.Action.new(_foresight, "search your library for three cards and exile them, then shuffle", null, true)).spell(DelayedDrawEffect.new())
		"Diminishing Returns": c.spell(F.Action.new(_returns, "shuffle both hands and graveyards into libraries, exile your top ten, then each player may draw up to seven", null, true))
		"Misinformation": c.spell(GraveTop.new(TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD, "target card in an opponent's graveyard").with_source_filter(_opponent_owned), 3))
		"Reinforcements": c.spell(GraveTop.new(TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD), 3))
		"Guerrilla Tactics":
			c.spell(DamageEffect.new(2).any_target())
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED, _guerrilla, "Deal 4 damage to any target.", _hostile_discard).targeting(TargetSpec.any_target(), F._enemy_first))
		_: return false
	return true

class DividedCounters extends CounterMarkerEffect:
	var temporary := false
	func _init(type: String, total: int, cleanup := false) -> void:
		super(type, total)
		divided_among(total)
		temporary = cleanup
	func resolve_multi(g: MtgGame, s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		for ref in targets:
			var i := g.find_instance(ref.instance_id)
			if i == null or i.zone != Mtg.Zone.BATTLEFIELD: continue
			g.add_counters(i, kind, ref.amount)
			if not temporary: continue
			# "For each +1/+1 counter you put on a creature this way, remove
			# a +1/+1 counter from that creature at the beginning of the
			# next cleanup step": one delayed trigger per counter, each on
			# the stack in the cleanup step (CR 514.3a).
			for _n in ref.amount:
				g.schedule_cleanup_action(load("res://cards/sets/all/_spells.gd")._remove_counters.bind(i.id, i.layer_timestamp, kind, 1), s, pid, "Remove a %s counter from %s." % [kind, i.data.card_name])
	func describe() -> String: return "divide %d %s counters among target creatures%s" % [count, kind, "; remove those counters at the next cleanup" if temporary else ""]

class Denial extends CounterEffect:
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		var who := spell.controller_id
		g.counter_spell(spell)
		var rules := load("res://cards/sets/all/_spells.gd")
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, rules._draw_up_to.bind(who, 2), "That spell's controller may draw up to two cards.", rules._later_turn.bind(g.turn_number)), pid, s)
		DelayedDrawEffect.new().resolve(g, s, pid, null)

class Burnout extends CounterEffect:
	func _init() -> void:
		super("target instant spell", _instant)
	static func _instant(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.INSTANT)
	func affects_spell(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.U) != 0
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if affects_spell(i): g.counter_spell(i)

class ExileAttacker extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target nonwhite attacking creature", _nonwhite).with_game_filter(_attacking)
	static func _nonwhite(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.W) == 0
	static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		var toughness := i.cur_toughness
		g.exile_permanent(i)
		g.adjust_life(pid, maxi(0, toughness))
	func describe() -> String: return "exile target nonwhite attacking creature; gain life equal to its toughness"

class GraveTop extends EffectBase:
	func _init(spec: TargetSpec, maximum: int) -> void:
		target_spec = spec
		target_min = 0
		target_max = maximum
		resolves_untargeted = true
		ai_helpful = spec.kind == TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD
	func resolve_multi(g: MtgGame, _s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		var cards: Array[CardInstance] = []
		for ref in targets: cards.append(g.find_instance(ref.instance_id))
		var ordered: Array[CardInstance] = []
		while not cards.is_empty():
			var chosen := g.agents[pid].choose_card(g, pid, cards, "Choose the next card from the top")
			if chosen == null or not cards.has(chosen): chosen = cards[0]
			ordered.append(chosen)
			cards.erase(chosen)
		ordered.reverse()
		for card in ordered: g.return_from_graveyard_to_library_top(card)
	func describe() -> String: return "put up to %d target cards from the graveyard on top of their owner's library in any order" % target_max

static func _remove_counters(g: MtgGame, id: int, stamp: int, kind: String, amount: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.remove_counters(i, kind, amount)
static func _later_turn(g: MtgGame, _s: CardInstance, _e: GameEvent, turn: int) -> bool: return g.turn_number > turn
static func _draw_up_to(g: MtgGame, _s: CardInstance, _e: GameEvent, who: int, maximum: int) -> void:
	var options: Array[String] = []
	for n in maximum + 1: options.append("Draw %d card(s)" % n)
	var number := clampi(g.agents[who].choose_option(g, who, options, "How many cards to draw?", mini(maximum, g.players[who].library.size())), 0, maximum)
	g.draw_cards(who, number)
static func _arc(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null: return
	var i := g.find_instance(t.instance_id)
	g.untap_permanent(i)
	g.continuous.add_floating_static(s, StaticAbility.new(_arc_shield.bind(i.id), "Prevent combat damage dealt by and to this creature."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()
static func _arc_shield(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null:
		i.cur_prevent_combat_damage_dealt = true
		i.cur_prevent_combat_damage_taken = true
static func _hail(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var all := g.all_battlefield().duplicate()
	g.begin_simultaneous()
	for i in all:
		if i.is_creature() and g.combat.attackers.has(i.id): g.deal_damage(s, TargetRef.card(i), 2)
	for i in all:
		if i.is_creature() and i.controller_id == pid: g.deal_damage(s, TargetRef.card(i), 1)
	g.deal_damage(s, TargetRef.player(pid), 1)
	g.end_simultaneous()
static func _war_cry_window(g: MtgGame, _pid: int) -> String:
	return "" if g.current_step() in [Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS] else "Cast only during combat before blockers are declared"
static func _war_cry(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): g.continuous.add_floating_static(s, StaticAbility.new(_menace.bind(i.id), "Menace."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()
static func _menace(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: i.cur_min_blockers = maxi(2, i.cur_min_blockers)
static func _legacy(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var candidates: Array[CardInstance] = g.players[pid].hand.duplicate()
	if candidates.is_empty(): return
	var card := g.agents[pid].choose_card(g, pid, candidates, "Shuffle a card from your hand into your library", false, true)
	if card == null or not candidates.has(card): return
	g.put_from_hand_on_top_of_library(card)
	g.shuffle_library(pid)
	DelayedDrawEffect.new(2).resolve(g, s, pid, null)
static func _foresight(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for n in mini(3, g.players[pid].library.size()):
		var cards: Array[CardInstance] = g.players[pid].library.duplicate()
		var selected := g.agents[pid].choose_card(g, pid, cards, "Choose a card to exile from your library", false, true)
		if selected != null and cards.has(selected): g.exile_library_card(selected)
	g.shuffle_library(pid)
static func _returns(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for who in [g.active_player, 1 - g.active_player]: g.shuffle_hand_and_graveyard_into_library(who)
	for n in mini(10, g.players[pid].library.size()): g.exile_top_of_library(pid, false)
	for who in [g.active_player, 1 - g.active_player]: _draw_up_to(g, s, null, who, 7)
static func _hostile_discard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.instance == s and bool(e.data.get("by_effect", false)) and int(e.data.get("effect_controller", -1)) == 1 - s.owner_id
static func _opponent_owned(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return s.controller_id != i.owner_id
static func _guerrilla(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for target in g.current_targets(): g.deal_damage(s, target, 4)
