extends RefCounted
## Weatherlight (_triggers, Pack 8). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Every listed name implements its whole Oracle text. Each trigger is a real
## stack trigger (TriggeredAbility); "you" is the trigger's controller — the
## seat it went on the stack for, which for a dies trigger is the player who
## controlled the creature last (CR 603.3a, 608.2h), read through
## MtgGame.current_resolution_controller(). A trigger whose effect touches
## its own source checks it is still the same object (CR 400.7,
## F._same_trigger_source); one that only uses it as a damage source keeps
## going on last known information (CR 608.2h). The one intervening "if"
## (Urborg Stalker) is checked on triggering and again on resolution
## (CR 603.4). Circling Vultures' discard from hand is the E7 special action
## (CardData.with_discard_special_action, MtgGame.discard_as_special_action).
const F := preload("res://cards/sets/fem/_rules.gd")
const B := preload("res://cards/sets/all/_basic.gd")
const P := preload("res://cards/sets/ice/_patterns.gd")

const ETB := Mtg.EventType.ENTERS_BATTLEFIELD
const DIES := Mtg.EventType.DIES
const UPKEEP := Mtg.EventType.UPKEEP_START

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Angelic Renewal":
			c.triggered(TriggeredAbility.new(DIES, _renewal, "Whenever a creature is put into your graveyard from the battlefield, you may sacrifice this enchantment. If you do, return that card to the battlefield.", _your_creature_died).capturing(_dead_card_context))
		"Mistmoon Griffin":
			c.triggered(TriggeredAbility.new(DIES, _mistmoon, "When this creature dies, exile it, then return the top creature card of your graveyard to the battlefield.", F._self_enter).capturing(_own_grave_context))
		"Peacekeeper":
			c.triggered(TriggeredAbility.new(UPKEEP, F._upkeep_payment.bind("{1}{W}"), "At the beginning of your upkeep, sacrifice this creature unless you pay {1}{W}.", F._your_upkeep))
			c.static_ability(StaticAbility.new(_no_attacks, "Creatures can't attack."))
		"Serenity":
			c.triggered(TriggeredAbility.new(UPKEEP, _serenity, "At the beginning of your upkeep, destroy all artifacts and enchantments. They can't be regenerated.", F._your_upkeep))
		# ------------------------------------------------------------- blue
		"Merfolk Traders":
			c.triggered(TriggeredAbility.new(ETB, _loot, "When this creature enters, draw a card, then discard a card.", F._self_enter))
		"Noble Benefactor":
			c.triggered(TriggeredAbility.new(DIES, _benefactor, "When this creature dies, each player may search their library for a card and put that card into their hand. Then each player who searched their library this way shuffles.", F._self_enter))
		"Pendrell Mists":
			var tax := TriggeredAbility.new(UPKEEP, F._upkeep_payment.bind("{1}"), "At the beginning of your upkeep, sacrifice this creature unless you pay {1}.", F._your_upkeep).capturing(F._source_context)
			c.static_ability(StaticAbility.new(_mists.bind(tax), "All creatures have \"At the beginning of your upkeep, sacrifice this creature unless you pay {1}.\"").changing_abilities().granting_triggers([UPKEEP]))
		"Sage Owl":
			c.triggered(TriggeredAbility.new(ETB, _sage_owl, "When this creature enters, look at the top four cards of your library, then put them back in any order.", F._self_enter))
		"Timid Drake":
			c.triggered(TriggeredAbility.new(ETB, _timid, "When another creature enters, return this creature to its owner's hand.", _another_creature_entered))
		"Tolarian Serpent":
			c.triggered(TriggeredAbility.new(UPKEEP, _serpent, "At the beginning of your upkeep, mill seven cards.", F._your_upkeep))
		# ------------------------------------------------------------ black
		"Abyssal Gatekeeper":
			c.triggered(TriggeredAbility.new(DIES, _gatekeeper, "When this creature dies, each player sacrifices a creature of their choice.", F._self_enter))
		"Barrow Ghoul", "Circling Vultures":
			if c.card_name == "Circling Vultures": c.with_discard_special_action()   # "You may discard this card any time you could cast an instant."
			c.triggered(TriggeredAbility.new(UPKEEP, _barrow, "At the beginning of your upkeep, sacrifice this creature unless you exile the top creature card of your graveyard.", F._your_upkeep))
		"Festering Evil":
			c.triggered(TriggeredAbility.new(UPKEEP, _festering, "At the beginning of your upkeep, this enchantment deals 1 damage to each creature and each player.", F._your_upkeep))
			c.activated(ActivatedAbility.new("{B}{B}", false, [DamageAllEffect.new(3).and_each_player()],
				"{B}{B}, Sacrifice this enchantment: It deals 3 damage to each creature and each player.").with_sacrifice_cost())
		"Fledgling Djinn":
			c.triggered(TriggeredAbility.new(UPKEEP, _djinn, "At the beginning of your upkeep, this creature deals 1 damage to you.", F._your_upkeep))
		"Odylic Wraith":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _wraith, "Whenever this creature deals damage to a player, that player discards a card.", _hit_player))
		"Urborg Stalker":
			c.triggered(TriggeredAbility.new(UPKEEP, _stalker, "At the beginning of each player's upkeep, if that player controls a nonblack, nonland permanent, this creature deals 1 damage to that player.", _stalker_if))
		# -------------------------------------------------------------- red
		"Aether Flash":
			c.triggered(TriggeredAbility.new(ETB, _aether_flash, "Whenever a creature enters, this enchantment deals 2 damage to it.", _creature_entered).capturing(_entering_context))
		"Bogardan Firefiend":
			c.triggered(TriggeredAbility.new(DIES, _firefiend, "When this creature dies, it deals 2 damage to target creature.", F._self_enter).targeting(TargetSpec.creature(), F._enemy_first))
		"Cinder Giant":
			c.triggered(TriggeredAbility.new(UPKEEP, _cinder, "At the beginning of your upkeep, this creature deals 2 damage to each other creature you control.", F._your_upkeep))
		"Goblin Bomb":
			c.triggered(TriggeredAbility.new(UPKEEP, _bomb, "At the beginning of your upkeep, you may flip a coin. If you win the flip, put a fuse counter on this enchantment. If you lose the flip, remove a fuse counter from this enchantment.", F._your_upkeep))
			c.activated(ActivatedAbility.new("", false, [DamageEffect.new(20).target_player()],
				"Remove five fuse counters from this enchantment and sacrifice it: It deals 20 damage to target player or planeswalker.").with_counter_cost("fuse", 5).with_sacrifice_cost())
		"Hurloon Shaman":
			c.triggered(TriggeredAbility.new(DIES, _hurloon, "When this creature dies, each player sacrifices a land of their choice.", F._self_enter))
		"Lava Hounds":
			c.triggered(TriggeredAbility.new(ETB, _hounds, "When this creature enters, it deals 4 damage to you.", F._self_enter))
		"Roc Hatchling":
			c.with_enters_counters("shell", 4)
			c.triggered(TriggeredAbility.new(UPKEEP, _shell, "At the beginning of your upkeep, remove a shell counter from this creature.", F._your_upkeep))
			c.static_ability(StaticAbility.new(_hatched_size, "As long as this creature has no shell counters on it, it gets +3/+2."))
			c.static_ability(StaticAbility.new(_hatched_wings, "As long as this creature has no shell counters on it, it has flying.").changing_abilities())
		# ------------------------------------------------------------ green
		"Barishi":
			c.triggered(TriggeredAbility.new(DIES, _barishi, "When this creature dies, exile it, then shuffle all creature cards from your graveyard into your library.", F._self_enter).capturing(_own_grave_context))
		"Fallow Wurm":
			c.triggered(TriggeredAbility.new(ETB, _fallow, "When this creature enters, sacrifice it unless you discard a land card.", F._self_enter))
		"Harvest Wurm":
			c.triggered(TriggeredAbility.new(ETB, _harvest, "When this creature enters, sacrifice it unless you return a basic land card from your graveyard to your hand.", F._self_enter))
		"Liege of the Hollows":
			c.triggered(TriggeredAbility.new(DIES, _liege, "When this creature dies, each player may pay any amount of mana. Then each player creates a number of 1/1 green Squirrel creature tokens equal to the amount of mana they paid this way.", F._self_enter))
		"Llanowar Sentinel":
			c.triggered(TriggeredAbility.new(ETB, _sentinel, "When this creature enters, you may pay {1}{G}. If you do, search your library for a card named Llanowar Sentinel, put that card onto the battlefield, then shuffle.", F._self_enter))
		"Rogue Elephant":
			c.triggered(TriggeredAbility.new(ETB, _rogue, "When this creature enters, sacrifice it unless you sacrifice a Forest.", F._self_enter))
		"Striped Bears":
			c.triggered(TriggeredAbility.new(ETB, _draw_one, "When this creature enters, draw a card.", F._self_enter))
		"Sylvan Hierophant":
			var other := TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD, "another target creature card in your graveyard").with_source_filter(_not_source)
			c.triggered(TriggeredAbility.new(DIES, _hierophant, "When this creature dies, exile it, then return another target creature card from your graveyard to your hand.", F._self_enter).capturing(_own_grave_context).targeting(other, _priciest_first))
		"Veteran Explorer":
			c.triggered(TriggeredAbility.new(DIES, _explorer, "When this creature dies, each player may search their library for up to two basic land cards, put them onto the battlefield, then shuffle.", F._self_enter))
		# --------------------------------------------------------- artifact
		"Straw Golem":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _straw, "When an opponent casts a creature spell, sacrifice this creature.", _opponent_creature_spell))
		_: return false
	return true


# ------------------------------------------------------------- shared --

## The seat the resolving trigger belongs to — "you" (CR 603.3a; a dies
## trigger's is the creature's LAST controller, CR 608.2h).
static func _you(g: MtgGame) -> int: return g.current_resolution_controller()

## APNAP (CR 101.4): the active player chooses first.
static func _apnap(g: MtgGame) -> Array[int]: return [g.active_player, g.opponent_of(g.active_player)]

static func _own_grave_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": int(e.data.get("controller", s.controller_id)),
		"entry": int(e.data.get("graveyard_entry", s.graveyard_entry))}

## "Exile it": only the card that died THIS time, still in the graveyard it
## went to (CR 400.7) — a token has ceased to exist (CR 704.5e).
static func _exile_the_corpse(g: MtgGame, s: CardInstance) -> void:
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.trigger_context(s).get("entry", -1)):
		g.exile_from_graveyard(s)

static func _not_source(_g: MtgGame, source: CardInstance, inst: CardInstance) -> bool: return inst != source

static func _priciest_first(g: MtgGame, _s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return g.find_instance(a.instance_id).data.cost.mana_value() > g.find_instance(b.instance_id).data.cost.mana_value()

## Each player sacrifices one permanent of their choice: chosen in APNAP
## order, then sacrificed together (one event, CR 101.4 + 704.3).
static func _each_sacrifices(g: MtgGame, filter: Callable, what: String, rank: Callable) -> void:
	var picks: Array[CardInstance] = []
	for who in _apnap(g):
		var choices: Array[CardInstance] = []
		for i in g.players[who].battlefield:
			if filter.call(i): choices.append(i)
		if choices.is_empty(): continue
		choices.sort_custom(rank)
		var pick := g.agents[who].choose_card(g, who, choices, "Sacrifice " + what, false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		picks.append(pick)
	g.begin_simultaneous()
	for pick in picks: g.sacrifice_permanent(pick)
	g.end_simultaneous()

static func _cheapest_creature(a: CardInstance, b: CardInstance) -> bool:
	return a.cur_power + a.cur_toughness + a.data.cost.mana_value() < b.cur_power + b.cur_toughness + b.data.cost.mana_value()

static func _spent_land(a: CardInstance, b: CardInstance) -> bool:
	if a.tapped != b.tapped: return a.tapped
	return (a.cur_supertypes & Mtg.Supertype.BASIC) > (b.cur_supertypes & Mtg.Supertype.BASIC)

static func _basic_land(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0


# --------------------------------------------------------------- white --

static func _your_creature_died(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and dead != s and (dead.last_types & Mtg.CardType.CREATURE) != 0 and dead.owner_id == s.controller_id

static func _dead_card_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"id": e.data.instance.id, "entry": int(e.data.get("graveyard_entry", -1))}

## "You may sacrifice this enchantment. If you do, return that card": the
## return needs the sacrifice (a Renewal already gone cannot pay), and only
## the card that died this time comes back (CR 400.7).
static func _renewal(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var pid := _you(g)
	if not F._same_trigger_source(g, s) or s.controller_id != pid: return
	var card := g.find_instance(int(ctx.get("id", -1)))
	var there := card != null and card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(ctx.get("entry", -1))
	var name := card.data.card_name if card != null else "that creature"
	if not g.agents[pid].choose_yes_no(g, pid, "Sacrifice Angelic Renewal to return %s to the battlefield?" % name, there): return
	g.sacrifice_permanent(s)
	if there and card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(ctx.get("entry", -1)):
		g.reanimate(card, pid)

## Ruling: the top creature card returns even when the Griffin could not
## be exiled (it left the graveyard first).
static func _mistmoon(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	_exile_the_corpse(g, s)
	var grave := g.players[pid].graveyard
	for index in range(grave.size() - 1, -1, -1):
		if grave[index].is_creature():
			g.reanimate(grave[index], pid)
			return

static func _no_attacks(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_cant_attack = true

static func _artifact_or_enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)

static func _serenity(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	DestroyAllEffect.new("all artifacts and enchantments", _artifact_or_enchantment, false).resolve(g, s, _you(g), null)


# ---------------------------------------------------------------- blue --

static func _loot(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	g.draw_cards(pid, 1)
	if not g.players[pid].hand.is_empty():
		g.discard_cards(pid, g.agents[pid].choose_discard(g, pid, 1))

static func _benefactor(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for who in _apnap(g):
		if g.agents[who].choose_yes_no(g, who, "Noble Benefactor: search your library for a card and put it into your hand?", not g.players[who].library.is_empty()):
			g.search_library(who, Callable(), "Noble Benefactor: search your library for a card")

## Granted to every creature, one copy per Pendrell Mists (two Mists, two
## upkeep taxes — the cur_ lists are rebuilt from the printed ones each pass).
static func _mists(g: MtgGame, _s: CardInstance, tax: TriggeredAbility) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_triggered_abilities.append(tax)

static func _sage_owl(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var cards := P.top(g, pid, 4)
	if cards.is_empty(): return
	var names: Array = []
	for i in cards: names.append(i.data.card_name)
	g.reveal_information(pid, "Sage Owl — top of your library, top first", names)
	P.order(g, pid, pid, cards)

static func _another_creature_entered(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var other: CardInstance = e.data.get("instance")
	return other != null and other != s and other.is_creature()

static func _timid(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.return_to_hand(s)

static func _serpent(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	g.mill(_you(g), 7)


# --------------------------------------------------------------- black --

static func _gatekeeper(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	_each_sacrifices(g, B._creature, "a creature", _cheapest_creature)

## "Unless you exile the top creature card of your graveyard" — the creature
## card nearest the top (the graveyard's order is public, CR 404.2).
static func _barrow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var here := F._same_trigger_source(g, s) and s.controller_id == pid
	var grave := g.players[pid].graveyard
	var top: CardInstance = null
	for index in range(grave.size() - 1, -1, -1):
		if grave[index].is_creature():
			top = grave[index]
			break
	if top != null and g.agents[pid].choose_yes_no(g, pid, "Exile %s from your graveyard to keep %s?" % [top.data.card_name, s.data.card_name], here):
		g.exile_from_graveyard(top)
		return
	if here: g.sacrifice_permanent(s)

static func _festering(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	DamageAllEffect.new(1).and_each_player().resolve(g, s, _you(g), null)

static func _djinn(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.deal_damage(s, TargetRef.player(_you(g)), 1)

static func _hit_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and e.data.has("to_player") and int(e.data.get("amount", 0)) > 0

## "That player discards a card" — of their own choice.
static func _wraith(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.to_player)
	if not g.players[who].hand.is_empty():
		g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))

static func _nonblack_nonland(g: MtgGame, pid: int) -> bool:
	for i in g.players[pid].battlefield:
		if not i.is_land() and (i.cur_colors & Mtg.ManaColor.B) == 0: return true
	return false

static func _stalker_if(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return _nonblack_nonland(g, int(e.data.get("player", -1)))

static func _stalker(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.player)
	if _nonblack_nonland(g, who):   # the intervening "if", again (CR 603.4)
		g.deal_damage(s, TargetRef.player(who), 1)


# ----------------------------------------------------------------- red --

static func _creature_entered(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i.is_creature()

static func _entering_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"id": e.data.instance.id, "stamp": e.data.instance.layer_timestamp}

static func _aether_flash(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.get("id", -1)))
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(ctx.get("stamp", -1)):
		g.deal_damage(s, TargetRef.card(i), 2)

static func _firefiend(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets(): g.deal_damage(s, t, 2)

static func _cinder(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var same := F._same_trigger_source(g, s)
	DamageAllEffect.new(2, "each other creature you control",
		func(i: CardInstance) -> bool: return i.controller_id == pid and not (i == s and same)).resolve(g, s, pid, null)

static func _bomb(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	if not g.agents[pid].choose_yes_no(g, pid, "Goblin Bomb: flip a coin?", int(s.counters.get("fuse", 0)) < 5): return
	var won := g.flip_coin(pid)
	if not F._same_trigger_source(g, s): return
	if won: g.add_counters(s, "fuse")
	else: g.remove_counters(s, "fuse", 1)

static func _hurloon(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	_each_sacrifices(g, B._land, "a land", _spent_land)

static func _hounds(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.deal_damage(s, TargetRef.player(_you(g)), 4)

static func _shell(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.remove_counters(s, "shell", 1)

static func _hatched_size(_g: MtgGame, s: CardInstance) -> void:
	if int(s.counters.get("shell", 0)) == 0:
		s.cur_power += 3
		s.cur_toughness += 2

static func _hatched_wings(_g: MtgGame, s: CardInstance) -> void:
	if int(s.counters.get("shell", 0)) == 0 and not s.cur_keywords.has(Mtg.Keyword.FLYING):
		s.cur_keywords.append(Mtg.Keyword.FLYING)


# --------------------------------------------------------------- green --

## Ruling: the creature cards are shuffled in even when Barishi could not
## be exiled.
static func _barishi(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	_exile_the_corpse(g, s)
	for card in g.players[pid].graveyard.duplicate():
		if card.is_creature(): g.return_from_graveyard_to_library_top(card)
	g.shuffle_library(pid)

static func _fallow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var here := F._same_trigger_source(g, s) and s.controller_id == pid
	var lands: Array[CardInstance] = []
	for i in g.players[pid].hand:
		if i.is_land(): lands.append(i)
	if not lands.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Discard a land card to keep Fallow Wurm?", here):
		var pick := g.agents[pid].choose_card(g, pid, lands, "Fallow Wurm: discard a land card", false, true)
		if pick == null or not lands.has(pick): pick = lands[0]
		g.discard_cards(pid, [pick])
		return
	if here: g.sacrifice_permanent(s)

static func _harvest(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var here := F._same_trigger_source(g, s) and s.controller_id == pid
	var lands: Array[CardInstance] = []
	for i in g.players[pid].graveyard:
		if _basic_land(i): lands.append(i)
	if not lands.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Return a basic land card from your graveyard to your hand to keep Harvest Wurm?", here):
		var pick := g.agents[pid].choose_card(g, pid, lands, "Harvest Wurm: return a basic land card to your hand")
		if pick == null or not lands.has(pick): pick = lands[0]
		g.return_from_graveyard_to_hand(pick)
		return
	if here: g.sacrifice_permanent(s)

static func _rogue(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	var here := F._same_trigger_source(g, s) and s.controller_id == pid
	var forests: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.has_subtype("forest") and i != s: forests.append(i)
	forests.sort_custom(_spent_land)
	if not forests.is_empty() and g.agents[pid].choose_yes_no(g, pid, "Sacrifice a Forest to keep Rogue Elephant?", here):
		var pick := g.agents[pid].choose_card(g, pid, forests, "Rogue Elephant: sacrifice a Forest", false, true)
		if pick == null or not forests.has(pick): pick = forests[0]
		g.sacrifice_permanent(pick)
		return
	if here: g.sacrifice_permanent(s)

## "Each player may pay any amount of mana": asked in APNAP order, paid as
## answered, and only then are the Squirrels made (CR 101.4).
static func _liege(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var paid := {}
	for who in _apnap(g):
		var most := 0
		while most < 99 and g.can_afford_cost(who, ManaCost.parse("{%d}" % (most + 1))): most += 1
		var n := 0
		if most > 0:
			n = g.agents[who].choose_number(g, who, 0, most, "Liege of the Hollows: pay how much mana (one Squirrel per mana)?", most)
		if n > 0 and not g.try_pay(who, ManaCost.parse("{%d}" % n)): n = 0
		paid[who] = n
	for who in _apnap(g):
		if int(paid[who]) <= 0: continue
		var squirrel := CardData.new("Squirrel", "", Mtg.CardType.CREATURE).pt(1, 1).with_colors(Mtg.ManaColor.G).with_subtypes(["squirrel"])
		g.create_token(who, squirrel, int(paid[who]))

static func _llanowar_sentinel(i: CardInstance) -> bool: return i.data.card_name == "Llanowar Sentinel"

static func _sentinel(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{1}{G}"), "Pay {1}{G} to search for a Llanowar Sentinel?", true):
		g.search_library(pid, _llanowar_sentinel, "Search your library for a card named Llanowar Sentinel", true)

static func _draw_one(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(_you(g), 1)

## The target was named as the trigger went on the stack (CR 603.3d); an
## illegal one fizzles the whole trigger (CR 608.2b), exile included.
static func _hierophant(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	_exile_the_corpse(g, s)
	for t in g.current_targets():
		var card := g.find_instance(t.instance_id)
		if card != null and card.zone == Mtg.Zone.GRAVEYARD: g.return_from_graveyard_to_hand(card)

## Each player may search for up to two basic lands; each who searched
## shuffles once at the end (CR 701.19a).
static func _explorer(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for who in _apnap(g):
		if not g.agents[who].choose_yes_no(g, who, "Veteran Explorer: search your library for up to two basic land cards?", true): continue
		for n in 2:
			g.search_library(who, _basic_land, "Veteran Explorer: search for a basic land card (%d of up to 2)" % (n + 1), true, false)
		g.shuffle_library(who)


# ------------------------------------------------------------ artifact --

static func _opponent_creature_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var spell: CardInstance = e.data.get("instance")
	return spell != null and spell.is_creature() and int(e.data.get("controller", -1)) != s.controller_id

static func _straw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and s.controller_id == _you(g): g.sacrifice_permanent(s)
