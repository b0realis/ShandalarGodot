extends RefCounted
## Urza's Legacy (_artifacts, Pack 10). Noncreature artifacts and artifact
## creatures with abilities.
##
## Every listed name implements its whole Oracle text; the shared helpers
## (the triggers' "you", APNAP, the put-from-hand effect) are Urza's Saga's
## (cards/sets/usg/_artifacts.gd). tests/cards/test_pack_10_B8_*.gd pin
## each card.
##
## Angel's Trumpet — a layer-6 vigilance grant to every creature, and an
##   END_STEP_START trigger for each player that counts only the creatures it
##   actually tapped (CR 608.2c); "didn't attack this turn" is
##   CardInstance.attacked_this_turn.
## Beast of Burden — a characteristic-defining P/T (CR 604.3) on the
##   battlefield (it counts itself) and in every other zone
##   (CardData.characteristic_definition, Maro's shape).
## Crawlspace — MtgGame.max_attackers (Caverns of Despair), written only while
##   its controller is the defending player: in a two-player game every
##   creature that attacks attacks "you" then. Two caps keep the lower.
## Defense Grid — a spell cost modifier for every caster, read off the
##   active player (Sphere of Resistance's shape); abilities are not spells.
## Iron Maiden / Wheel of Torture — "each opponent's upkeep", X counted as
##   the trigger resolves; X of 0 or less deals nothing.
## Memory Jar — Mangara's Tome's face-down exile (MtgGame.exile_from_hand,
##   nobody may look, CR 406.3): each player in APNAP order, then the seven
##   draws; the delayed trigger (CR 603.7) keeps [id, exile_entry] rows so a
##   card that left exile and came back is not "a card exiled this way"
##   (CR 400.7). The end-step discard is an effect's discard (Library of
##   Leng, Megrim and Metrognome see it); the returns are logged without
##   names, so the other seat never learns the hidden hand.
## Quicksilver Amulet — Copper Gnomes's effect for a creature card
##   (usg/_artifacts.gd `FromHand`).
## Scrapheap — Femeref Enchantress's LEAVES_BATTLEFIELD reading (vis/_triggers.gd):
##   "put into a graveyard" is the card's zone as the event is dispatched (a
##   token is there too, briefly — CR 111.7), the types are last known
##   (CR 608.2h), "your graveyard" its owner's; the Scrapheap hears its own
##   departure (CR 603.10a).
## Thran Lens — a layer-5 colour change of every permanent (Celestial Dawn's
##   shape, timestamp order with Darkest Hour); spells and cards in other
##   zones keep their colours. Under the 1997 rule a tapped Lens stops.
const F := preload("res://cards/sets/fem/_rules.gd")
const U := preload("res://cards/sets/usg/_artifacts.gd")
const PATH := "res://cards/sets/ulg/_artifacts.gd"

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Angel's Trumpet":
			c.static_ability(StaticAbility.new(_vigilance, "All creatures have vigilance.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _trumpet,
				"At the beginning of each player's end step, tap all untapped creatures that player controls that didn't attack this turn. This artifact deals damage to the player equal to the number of creatures tapped this way.",
				U.each_players))
		"Beast of Burden":
			c.static_ability(StaticAbility.new(_burden,
				"Beast of Burden's power and toughness are each equal to the number of creatures on the battlefield.").setting_base_pt())
			c.characteristic_definition = _burden
		"Crawlspace":
			c.static_ability(StaticAbility.new(_crawlspace, "No more than two creatures can attack you each combat."))
		"Defense Grid":
			c.with_cost_modifier(_grid)
		"Iron Maiden":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _maiden,
				"At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is the number of cards in their hand minus 4.",
				U.opponents))
		"Jhoira's Toolbox":
			c.activated(ActivatedAbility.new("{2}", false,
				[RegenerateEffect.new().target_creature("target artifact creature", _artifact_creature)],
				"{2}: Regenerate target artifact creature."))
		"Memory Jar":
			c.activated(ActivatedAbility.new("", true, [Jar.new()],
				"{T}, Sacrifice this artifact: Each player exiles all cards from their hand face down and draws seven cards. At the beginning of the next end step, each player discards their hand and returns to their hand each card they exiled this way.") \
				.with_sacrifice_cost())
		"Quicksilver Amulet":
			c.activated(ActivatedAbility.new("{4}", true, [U.FromHand.new(Mtg.CardType.CREATURE, "a creature")],
				"{4}, {T}: You may put a creature card from your hand onto the battlefield."))
		"Scrapheap":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _scrapheap,
				"Whenever an artifact or enchantment is put into your graveyard from the battlefield, you gain 1 life.",
				_into_your_graveyard))
		"Thran Lens":
			c.static_ability(StaticAbility.new(_lens, "All permanents are colorless.").changing_colors())
		"Wheel of Torture":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wheel,
				"At the beginning of each opponent's upkeep, this artifact deals X damage to that player, where X is 3 minus the number of cards in their hand.",
				U.opponents))
		_: return false
	return true


static func _artifact_creature(i: CardInstance) -> bool:
	return i.is_creature() and i.is_type(Mtg.CardType.ARTIFACT)


# ------------------------------------------------------------ Angel's Trumpet --

static func _vigilance(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and not i.cur_keywords.has(Mtg.Keyword.VIGILANCE):
			i.cur_keywords.append(Mtg.Keyword.VIGILANCE)

static func _trumpet(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var tapped := 0
	for i in g.players[who].battlefield.duplicate():
		if i.is_creature() and not i.tapped and not i.attacked_this_turn:
			g.tap_permanent(i)
			if i.tapped: tapped += 1
	if tapped > 0:
		g.deal_damage(s, TargetRef.player(who), tapped)


# ------------------------------------------------------------ Beast of Burden --

static func _burden(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in g.all_battlefield():
		if i.is_creature(): n += 1
	s.cur_power = n
	s.cur_toughness = n


# ----------------------------------------------------------------- Crawlspace --

static func _crawlspace(g: MtgGame, s: CardInstance) -> void:
	if g.active_player == s.controller_id: return
	g.max_attackers = 2 if g.max_attackers <= 0 else mini(g.max_attackers, 2)


# --------------------------------------------------------------- Defense Grid --

## "Each spell costs {3} more to cast except during its controller's turn."
static func _grid(g: MtgGame, caster: int, _data: CardData, _source: CardInstance) -> int:
	return 3 if g.active_player != caster else 0


# ----------------------------------------------- Iron Maiden / Wheel of Torture --

static func _maiden(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var x := g.players[who].hand.size() - 4
	if x > 0: g.deal_damage(s, TargetRef.player(who), x)

static func _wheel(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var x := 3 - g.players[who].hand.size()
	if x > 0: g.deal_damage(s, TargetRef.player(who), x)


# ----------------------------------------------------------------- Memory Jar --

class Jar extends EffectBase:
	func _init() -> void:
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var exiled: Array = []
		for who in U.apnap(g):
			var rows: Array = []
			for card in g.players[who].hand.duplicate():
				g.exile_from_hand(card, true, -1)
				if card.zone == Mtg.Zone.EXILE: rows.append([card.id, card.exile_entry])
			exiled.append([who, rows])
		for who in U.apnap(g):
			g.draw_cards(who, 7)
		var module: GDScript = load(PATH)
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, module._jar_return,
			"At the beginning of the next end step, each player discards their hand and returns to their hand each card they exiled this way."),
			pid, s, false, {"exiled": exiled})
	func describe() -> String:
		return "each player exiles their hand face down and draws seven cards; at the next end step each player discards their hand and gets the exiled cards back"

static func _jar_return(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var exiled: Array = memory.get("exiled", [])
	for who in U.apnap(g):
		g.discard_cards(who, g.players[who].hand.duplicate())
	for who in U.apnap(g):
		for pair in exiled:
			if int(pair[0]) != who: continue
			for row in pair[1]:
				var card := g.find_instance(int(row[0]))
				if card != null and card.zone == Mtg.Zone.EXILE and card.exile_entry == int(row[1]):
					g.return_from_exile_to_hand(card, false)


# ------------------------------------------------------------------ Scrapheap --

static func _into_your_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var gone: CardInstance = e.data.get("instance")
	if gone == null or gone.zone != Mtg.Zone.GRAVEYARD: return false
	if (gone.last_types & (Mtg.CardType.ARTIFACT | Mtg.CardType.ENCHANTMENT)) == 0: return false
	# The departing Scrapheap's "you" is the player who controlled it as it left.
	var you := int(e.data.get("from_controller", s.controller_id)) if gone == s else s.controller_id
	return gone.owner_id == you

static func _scrapheap(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.adjust_life(U.you(g, s), 1)


# ----------------------------------------------------------------- Thran Lens --

static func _lens(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		i.cur_colors = 0
