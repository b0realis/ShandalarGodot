extends RefCounted
## Portal's entering, attacking and death triggers. Choices use the normal
## decision funnel; targeted triggers announce targets before responses.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Venerable Monk": enter(c, GainLifeEffect.new(2))
		"Spiritual Guardian": enter(c, GainLifeEffect.new(4))
		"Serpent Warrior": enter(c, GainLifeEffect.new(-3))
		"Dread Reaper": enter(c, GainLifeEffect.new(-5))
		"Man-o'-War": enter(c, ReturnToHandEffect.new())
		"Fire Imp": enter(c, DamageEffect.new(2).target_creature())
		"Fire Dragon": enter(c, MountainDamage.new())
		"Gravedigger": enter(c, ReturnFromGraveyardEffect.new(), true)
		"Serpent Assassin": enter(c, DestroyEffect.new(TargetSpec.creature("target nonblack creature", S._nonblack)), true)
		"Ingenious Thief": enter(c, F.Action.new(_look, "look at target player's hand", TargetSpec.player()))
		"Ebon Dragon": enter(c, F.Action.new(_discard, "target opponent discards a card", TargetSpec.opponent()), true)
		"Wood Elves": enter(c, SearchLibraryEffect.new("a Forest card", S._subtype.bind("forest")).to_battlefield())
		"Owl Familiar":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _owl, "Draw a card, then discard a card.", F._self_enter))
		"Thundermare":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _mare, "Tap all other creatures.", F._self_enter))
		"Charging Paladin", "Charging Bandits":
			var power := 2 if c.card_name == "Charging Bandits" else 0
			var toughness := 3 if c.card_name == "Charging Paladin" else 0
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _charge.bind(power, toughness), "Gets %+d/%+d until end of turn." % [power, toughness], F._self_attack))
		"Seasoned Marshal":
			c.triggered(trigger(TapEffect.new(TargetSpec.creature()), Mtg.EventType.DECLARED_ATTACKERS, F._self_attack, true))
		"Fire Snake": c.triggered(trigger(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", S._land)), Mtg.EventType.DIES, F._self_enter))
		"Noxious Toad": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _toad, "Each opponent discards a card.", F._self_enter))
		"Alabaster Dragon", "Endless Cockroaches", "Undying Beast":
			var ability := TriggeredAbility.new(Mtg.EventType.DIES, _return_dead, c.oracle_text, F._self_enter).capturing(_death_context)
			c.triggered(ability)
		"Plant Elemental", "Primeval Force", "Mercenary Knight", "Thundering Wurm", "Pillaging Horde":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _unless, c.oracle_text, F._self_enter))
		"Thing from the Deep": c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _unless, c.oracle_text, F._self_attack))
		_: return false
	return true

static func trigger(effect: EffectBase, event: int, condition: Callable, optional := false) -> TriggeredAbility:
	var result := TriggeredAbility.new(event, _resolve.bind(effect, optional), effect.describe(), condition)
	if effect.target_spec != null:
		result.targeting(effect.target_spec, _target_order.bind(effect.ai_helpful or effect is ReturnFromGraveyardEffect))
	return result

static func enter(c: CardData, effect: EffectBase, optional := false) -> void:
	c.triggered(trigger(effect, Mtg.EventType.ENTERS_BATTLEFIELD, F._self_enter, optional))

static func _target_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef, helpful: bool) -> bool:
	var av := preload("res://cards/sets/ice/_patterns.gd").retarget_value(g, s.controller_id, s, a)
	var bv := preload("res://cards/sets/ice/_patterns.gd").retarget_value(g, s.controller_id, s, b)
	return av < bv if helpful else av > bv

static func _resolve(g: MtgGame, s: CardInstance, _e: GameEvent, effect: EffectBase, optional: bool) -> void:
	var pid := int(g.trigger_context(s).controller)
	var target: TargetRef = g.current_targets()[0] if not g.current_targets().is_empty() else null
	var hint := true
	if target != null and not target.is_player and not effect.ai_helpful and not effect is ReturnFromGraveyardEffect:
		hint = g.find_instance(target.instance_id).controller_id != pid
	if optional and not g.agents[pid].choose_yes_no(g, pid, s.data.card_name + ": " + effect.describe() + "?", hint): return
	effect.resolve(g, s, pid, target)

static func _look(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var names: Array = []
	for i in g.players[t.player_id].hand: names.append(i.data.card_name)
	g.reveal_information(pid, g.players[t.player_id].player_name + " — hand", names)

static func discard(g: MtgGame, pid: int, count: int) -> void:
	var cards: Array[CardInstance] = g.players[pid].hand.duplicate()
	var picks: Array[CardInstance] = []
	for n in mini(count, g.players[pid].hand.size()):
		var pick := g.agents[pid].choose_card(g, pid, cards, "Choose a card to discard", false, true)
		if pick == null or not cards.has(pick): pick = cards[0]
		picks.append(pick)
		cards.erase(pick)
	g.discard_cards(pid, picks)

static func _discard(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void: discard(g, t.player_id, 1)
static func _toad(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: discard(g, g.opponent_of(int(g.trigger_context(s).controller)), 1)
static func _owl(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	g.draw_cards(pid, 1)
	discard(g, pid, 1)
static func _mare(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i != s or not F._same_trigger_source(g, s)): g.tap_permanent(i)
static func _charge(g: MtgGame, s: CardInstance, _e: GameEvent, power: int, toughness: int) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_pump(s.id, power, toughness)
		g.recalculate()
static func _death_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"entry": s.graveyard_entry, "controller": e.data.get("controller", s.controller_id)}
static func _return_dead(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.trigger_context(s).entry):
		if s.data.card_name == "Endless Cockroaches": g.return_from_graveyard_to_hand(s)
		else: g.return_from_graveyard_to_library_top(s)
	# A shuffle instruction still shuffles when its card has left the graveyard.
	if s.data.card_name == "Alabaster Dragon": g.shuffle_library(s.owner_id)

static func _unless(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var name := s.data.card_name
	var from_hand := name in ["Mercenary Knight", "Thundering Wurm", "Pillaging Horde"]
	var number := 3 if name == "Primeval Force" else 1
	var cards: Array[CardInstance] = []
	var pool: Array[CardInstance] = g.players[pid].hand if from_hand else g.players[pid].battlefield
	for i in pool:
		if (name == "Mercenary Knight" and i.is_creature()) or (name == "Thundering Wurm" and i.is_land()) or name == "Pillaging Horde" or (not from_hand and i.has_subtype("island" if name == "Thing from the Deep" else "forest")):
			cards.append(i)
	var pay := cards.size() >= number and g.agents[pid].choose_yes_no(g, pid, "%s: %s %d %s to keep this creature?" % [name, "Discard" if from_hand else "Sacrifice", number, "card(s)" if from_hand else "land(s)"], true)
	if not pay:
		if F._same_trigger_source(g, s): g.sacrifice_permanent(s)
		return
	if name == "Pillaging Horde":
		g.discard_random(pid, 1)
		return
	var picks: Array[CardInstance] = []
	for n in number:
		var pick := g.agents[pid].choose_card(g, pid, cards, "Choose a card to " + ("discard" if from_hand else "sacrifice"), false, true)
		if pick == null or not cards.has(pick): pick = cards[0]
		picks.append(pick)
		cards.erase(pick)
	if from_hand: g.discard_cards(pid, picks)
	else:
		g.begin_simultaneous()
		for i in picks: g.sacrifice_permanent(i)
		g.end_simultaneous()

class MountainDamage extends DamageEffect:
	func _init() -> void:
		super(0)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var count := 0
		for i in g.players[pid].battlefield:
			if i.has_subtype("mountain"): count += 1
		g.deal_damage(s, t, count)
	func describe() -> String: return "deal damage equal to the number of Mountains you control"
