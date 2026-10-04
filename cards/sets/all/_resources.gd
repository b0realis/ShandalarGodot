extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const S := preload("res://cards/sets/all/_spells.gd")
const LAND_FOOD := {"Balduvian Trading Post": ["mountain", true], "Heart of Yavimaya": ["forest", false],
	"Kjeldoran Outpost": ["plains", false], "Lake of the Dead": ["swamp", false], "Soldevi Excavations": ["island", true]}

static func configure(c: CardData) -> bool:
	if LAND_FOOD.has(c.card_name): c.entry_payment = _land_payment.bind(LAND_FOOD[c.card_name][0], LAND_FOOD[c.card_name][1])
	match c.card_name:
		"Elvish Spirit Guide": c.mana(ManaAbility.new(Mtg.ManaColor.G).by_exiling_from_hand())
		"Balduvian Trading Post":
			c.mana(ManaAbility.new(Mtg.ManaColor.C).and_also(Mtg.ManaColor.R))
			c.activated(F._ability("{1}", true, DamageEffect.new(1).target_creature("target attacking creature")))
			c.activated_abilities[0].effects[0].target_spec.with_game_filter(_attacking)
		"Heart of Yavimaya":
			c.mana(ManaAbility.new(Mtg.ManaColor.G)).activated(F._ability("", true, PumpEffect.new(1, 1)))
		"Kjeldoran Outpost":
			c.mana(ManaAbility.new(Mtg.ManaColor.W)).activated(F._ability("{1}{W}", true, CreateTokenEffect.new("Soldier", 1, 1, Mtg.ManaColor.W, "soldier")))
		"Lake of the Dead":
			c.mana(ManaAbility.new(Mtg.ManaColor.B)).mana(ManaAbility.new(Mtg.ManaColor.B, 4).with_sacrifice_of("Swamp", F._subtype.bind("swamp")))
		"Soldevi Excavations":
			c.mana(ManaAbility.new(Mtg.ManaColor.C).and_also(Mtg.ManaColor.U)).activated(F._ability("{1}", true, F.Action.new(_scry, "scry 1", null, true)))
		"Sheltered Valley":
			c.entry_payment = _valley_entry
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _valley_life, "If you control three or fewer lands, gain 1 life.", _valley_upkeep))
		"Thawing Glaciers":
			c.with_enters_tapped()
			c.activated(F._ability("{1}", true, F.Action.new(_glaciers, "search for a basic land, put it onto the battlefield tapped, shuffle; return this land at the next cleanup", null, true)))
		"Sol Grail":
			c.as_it_enters(_grail_choice)
			c.mana(ManaAbility.new(Mtg.ManaColor.C).with_dynamic_color(_grail_color))
		"Astrolabe":
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color, 2).with_mana_cost("{1}").with_sacrifice().with_side_effect(_astrolabe))
		"Browse": c.activated(F._ability("{2}{U}{U}", false, F.Action.new(_browse, "look at the top five; put one into your hand and exile the rest", null, true)))
		"Ashnod's Cylix": c.activated(F._ability("{3}", true, F.Action.new(_cylix, "target player looks at their top three, puts one back and exiles the rest", TargetSpec.player())))
		"Soldevi Digger": c.activated(F._ability("{2}", false, F.Action.new(_digger, "put the top card of your graveyard on the bottom of your library", null, true)))
		"Soldevi Sage":
			var ability := F._ability("", true, F.Action.new(_sage, "draw three cards, then discard one of them", null, true)).with_sacrifice_of("land", B._land)
			ability.sacrifice_count = 2
			c.activated(ability)
		"Gorilla Shaman":
			var effect := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target noncreature artifact with mana value X", _noncreature_artifact).with_source_filter(_mana_value_x))
			c.activated(F._ability("{X}{X}{1}", false, effect))
		"Floodwater Dam":
			var effect := TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", B._land)).x_targets()
			c.activated(F._ability("{X}{X}{1}", true, effect))
		"Phyrexian Devourer":
			c.activated(F._ability("", false, F.Action.new(_devour, "put +1/+1 counters equal to the exiled card's mana value on this creature", null, true)).with_library_exile_cost(1))
			c.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK, _devourer_sacrifice, "Sacrifice this creature if its power is 7 or greater.", _too_large))
		"Helm of Obedience": c.activated(F._ability("{X}", true, F.Action.new(_helm, "opponent mills until X cards or a creature enters their graveyard; sacrifice this artifact and put that creature under your control", TargetSpec.opponent())).with_min_x(1))
		"Balduvian Dead":
			c.activated(F._ability("{2}{R}", false, F.Action.new(_dead, "create a 3/1 black and red Graveborn with haste; sacrifice it at the next end step", null, true)).with_exile_from_graveyard("creature card", B._creature))
		_: return false
	return true

static func _land_payment(g: MtgGame, _s: CardInstance, pid: int, type: String, untapped: bool) -> bool:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.has_subtype(type) and (not untapped or not i.tapped): choices.append(i)
	if choices.is_empty(): return false
	# The controller's OWN choice, not "of an opponent's choice": ORDERED, not
	# adverse, so a human seat may also withdraw the land play
	# (MtgGame.cancel_choice) and a heuristic seat still takes the first.
	var pick := g.agents[pid].choose_card(g, pid, choices, "Sacrifice %s%s or put the entering land into its owner's graveyard" % ["an untapped " if untapped else "a ", type], true, false, true)
	if pick == null or not choices.has(pick): return false
	g.sacrifice_permanent(pick)
	return true
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _noncreature_artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT) and not i.is_creature()
static func _mana_value_x(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.data.cost.mana_value() == g.casting_x(s)
static func _scry(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if g.players[pid].library.is_empty(): return
	var top: CardInstance = g.players[pid].library.back()
	var offered: Array[CardInstance] = [top]
	var picked := g.agents[pid].choose_card(g, pid, offered, "Scry 1: put this card on the bottom? (Cancel keeps it on top)", true, true)
	if picked == top: g.put_on_bottom_of_library(top)
static func _valley_entry(g: MtgGame, s: CardInstance, pid: int) -> bool:
	for i in g.players[pid].battlefield.duplicate():
		if i != s and i.data.card_name == "Sheltered Valley": g.sacrifice_permanent(i)
	return true
static func _land_count(g: MtgGame, pid: int) -> int:
	var result := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): result += 1
	return result
static func _valley_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return int(e.data.player) == s.controller_id and _land_count(g, s.controller_id) <= 3
static func _valley_life(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	if _land_count(g, pid) <= 3: g.adjust_life(pid, 1)
static func _basic(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0
static func _glaciers(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].library:
		if _basic(i): choices.append(i)
	var pick := g.agents[pid].choose_card(g, pid, choices, "Search for a basic land to put onto the battlefield tapped", true)
	if pick != null and choices.has(pick):
		g.put_library_card_onto_battlefield(pick, pid, true)
	g.shuffle_library(pid)
	# A delayed trigger on the stack in the cleanup step (CR 514.3a).
	if B.live_source(g, s): g.schedule_cleanup_action(_cleanup_return.bind(s.id, s.layer_timestamp), s, pid, "Return Thawing Glaciers to its owner's hand.")
static func _cleanup_return(g: MtgGame, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.return_to_hand(i)
static func _grail_choice(g: MtgGame, s: CardInstance, pid: int) -> void:
	g._rec(s, &"memory")
	s.memory["grail_color"] = g.agents[pid].choose_color(g, pid, "Choose a color for Sol Grail", Mtg.ManaColor.W)
static func _grail_color(_g: MtgGame, s: CardInstance) -> int: return int(s.memory.get("grail_color", Mtg.ManaColor.W))
static func _astrolabe(g: MtgGame, s: CardInstance, pid: int) -> void: DelayedDrawEffect.new().resolve(g, s, pid, null)
static func _peek(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var lib := g.players[pid].library
	for offset in mini(count, lib.size()): out.append(lib[lib.size() - 1 - offset])
	return out
static func _browse(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var choices := _peek(g, pid, 5)
	if choices.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, choices, "Browse: put one of these five cards into your hand")
	if pick == null or not choices.has(pick): pick = choices[0]
	g.library_card_to_hand(pick)
	choices.erase(pick)
	for i in choices: g.exile_library_card(i)
static func _cylix(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var choices := _peek(g, who, 3)
	if choices.is_empty(): return
	var pick := g.agents[who].choose_card(g, who, choices, "Ashnod's Cylix: keep one card on top")
	if pick == null or not choices.has(pick): pick = choices[0]
	choices.erase(pick)
	for i in choices: g.exile_library_card(i)
static func _digger(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not g.players[pid].graveyard.is_empty(): g.put_on_bottom_of_library(g.players[pid].graveyard.back())
static func _sage(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var before := g.players[pid].drawn_this_turn.size()
	g.draw_cards(pid, 3)
	B.discard_one_just_drawn(g, pid, before, "Soldevi Sage: discard one of the cards just drawn")
static func _devour(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not B.live_source(g, s): return
	var cards: Array = g.cost_paid("_library_exiled", [])
	if not cards.is_empty(): g.add_counters(s, "+1/+1", int(cards[0].mana_value))
static func _too_large(_g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return s.cur_power >= 7
static func _devourer_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and s.cur_power >= 7 and s.controller_id == int(g.trigger_context(s).controller): g.sacrifice_permanent(s)
static func _helm(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x: int) -> void:
	var put := 0
	var who := t.player_id
	while put < x and not g.players[who].library.is_empty():
		var top: CardInstance = g.players[who].library.back()
		g.mill(who, 1)
		if top.zone != Mtg.Zone.GRAVEYARD: continue
		put += 1
		if top.is_creature():
			if B.live_source(g, s) and s.controller_id == pid: g.sacrifice_permanent(s)
			g.reanimate(top, pid)
			break
static func _dead(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var token := CardData.new("Graveborn", "", Mtg.CardType.CREATURE).pt(3, 1).with_colors(Mtg.ManaColor.B | Mtg.ManaColor.R).with_subtypes(["graveborn"]).with_keywords([Mtg.Keyword.HASTE])
	for i in g.create_token(pid, token): g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _sacrifice_token.bind(i.id, i.layer_timestamp), "Sacrifice the Graveborn token."), pid, s)
static func _sacrifice_token(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.sacrifice_permanent(i)
