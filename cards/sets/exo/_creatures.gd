extends RefCounted
## Exodus (_creatures, Pack 9). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text — the keywords
## (flying, trample, legendary) are printed on the card files — with a
## typed effect wherever the vocabulary has one (the fair AI reads them,
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape (`self_keyword` for the flying breaths,
## `self_bounce` for the creatures that save themselves, `counter_spell`
## for Ertai, `exact_mv_removal` for Plaguebearer's X).
##
## THE KEEPERS. "Choose target opponent who <has more X> than you do as you
## activate this ability": the comparison is a TARGETING requirement on the
## opponent ([member TargetSpec.player_source_filter], judged from the
## activating seat), checked as the ability is activated (CR 601.2c,
## 602.2b) — the engine refuses an activation with no qualifying opponent.
## The Oracle's own "as you activate" makes it a fact about that moment, so
## the resolution does not judge the comparison again: the target is still
## re-checked for everything else (CR 608.2b — shroud, a player who has
## lost). Keeper of the Dead's second target is "target nonblack creature
## THAT PLAYER controls", a sibling-bound slot (TargetSpec.with_sibling_filter)
## that IS re-checked on resolution: a creature that changed hands is no
## longer that player's.
##
## Entropic Specter and Skyshroud War Beast choose an opponent as they
## enter (CR 614.12, Haunting Apparition's shape in mir/_creatures.gd);
## their characteristic-defining P/T counts the chosen player's hand or
## nonbasic lands live (CR 604.3). Off the battlefield they are their
## printed 0/0.
##
## Plaguebearer's "with mana value X" reads the X being proposed or paid
## (MtgGame.casting_x — Gorilla Shaman's shape, all/_resources.gd).
##
## tests/cards/test_pack_9_B11_creatures.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const LOOT := preload("res://cards/sets/atq/jalum_tome.gd")
const SCEPTER := preload("res://cards/sets/2ed/disrupting_scepter.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Keeper of the Light":
			c.activated(ActivatedAbility.new("{W}", true,
				[KeeperSlot.new(_more_life, "target opponent who has more life than you"), GainLifeEffect.new(3)],
				"{W}, {T}: Choose target opponent who has more life than you do as you activate this ability. You gain 3 life."))
		"Shield Mate":
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(0, 4).helpful()],
				"Sacrifice this creature: Target creature gets +0/+4 until end of turn.").with_sacrifice_cost())
		# ----------------------------------------------------------- blue
		"Ephemeron":
			# Role `self_bounce`: the fair AI's answer to an opposing spell
			# or ability aimed at it (alliances_tactics.gd).
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_self_to_hand, "return this creature to its owner's hand", null, true).with_ai_role(&"self_bounce")],
				"Discard a card: Return this creature to its owner's hand.").with_discard_cost(1))
		"Ertai, Wizard Adept":
			# Role `counter_spell` (Tidal Control's): fired in response to an
			# opposing spell that clears the pilot's counter bar.
			c.activated(ActivatedAbility.new("{2}{U}{U}", true, [CounterEffect.new().with_ai_role(&"counter_spell")],
				"{2}{U}{U}, {T}: Counter target spell."))
		"Keeper of the Mind":
			c.activated(ActivatedAbility.new("{U}", true,
				[KeeperSlot.new(_two_more_cards, "target opponent who has at least two more cards in hand than you"), DrawEffect.new(1)],
				"{U}, {T}: Choose target opponent who has at least two more cards in hand than you do as you activate this ability. Draw a card."))
		"Killer Whale", "Whiptongue Frog":
			c.activated(ActivatedAbility.new("{U}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff().with_ai_role(&"self_keyword", {"keyword": Mtg.Keyword.FLYING})],
				"{U}: This creature gains flying until end of turn."))
		"Merfolk Looter":
			c.activated(ActivatedAbility.new("", true, [LOOT.LootEffect.new()],
				"{T}: Draw a card, then discard a card."))
		"Rootwater Mystic":
			c.activated(ActivatedAbility.new("{1}{U}", false, [LibraryPeek.new()],
				"{1}{U}: Look at the top card of target player's library."))
		"Wayward Soul":
			# Role `self_bounce`: the top of the library keeps the card from
			# a removal spell aimed at it, as a return to hand would.
			c.activated(ActivatedAbility.new("{U}", false,
				[F.Action.new(_self_to_library_top, "put this creature on top of its owner's library", null, true).with_ai_role(&"self_bounce")],
				"{U}: Put this creature on top of its owner's library."))
		# ---------------------------------------------------------- black
		"Cat Burglar":
			# The TARGET player chooses what they discard (Disrupting
			# Scepter's effect, 2ed/disrupting_scepter.gd).
			c.activated(ActivatedAbility.new("{2}{B}", true, [SCEPTER.ScepterEffect.new()],
				"{2}{B}, {T}: Target player discards a card. Activate only as a sorcery.").only_if(MA.sorcery_speed))
		"Entropic Specter":
			c.as_it_enters(_choose_opponent)
			c.static_ability(StaticAbility.new(_specter_size,
				"Entropic Specter's power and toughness are each equal to the number of cards in the chosen player's hand.").setting_base_pt())
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _specter_discard,
				"Whenever this creature deals damage to a player, that player discards a card.", _damages_a_player))
		"Keeper of the Dead":
			var victim := DestroyEffect.new(TargetSpec.creature("target nonblack creature that player controls", _nonblack) \
				.with_sibling_filter(_that_players, TargetSpec.WHY["controller"]))
			c.activated(ActivatedAbility.new("{B}", true,
				[KeeperSlot.new(_two_fewer_creature_cards, "target opponent who has at least two fewer creature cards in their graveyard than you"), victim],
				"{B}, {T}: Choose target opponent who has at least two fewer creature cards in their graveyard than you do as you activate this ability. Destroy target nonblack creature that player controls."))
		"Plaguebearer":
			# Role `exact_mv_removal` (Gorilla Shaman's): the AI sizes X to
			# the mana value of the opposing creature it can pay for.
			var plague := DestroyEffect.new(TargetSpec.creature("target nonblack creature with mana value X", _nonblack) \
				.with_source_filter(_mana_value_x))
			plague.with_ai_role(&"exact_mv_removal")
			c.activated(ActivatedAbility.new("{X}{X}{B}", false, [plague],
				"{X}{X}{B}: Destroy target nonblack creature with mana value X."))
		"Thrull Surgeon":
			c.activated(ActivatedAbility.new("{1}{B}", false, [SurgeonDiscard.new()],
				"{1}{B}, Sacrifice this creature: Look at target player's hand and choose a card from it. That player discards that card. Activate only as a sorcery.") \
				.with_sacrifice_cost().only_if(MA.sorcery_speed))
		"Vampire Hounds":
			var feast := ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()],
				"Discard a creature card: This creature gets +2/+2 until end of turn.").with_discard_cost(1)
			feast.discard_filter = _creature_card
			feast.discard_filter_desc = "creature card"
			c.activated(feast)
		# ------------------------------------------------------------ red
		"Furnace Brood":
			c.activated(ActivatedAbility.new("{R}", false, [NoRegeneration.new()],
				"{R}: Target creature can't be regenerated this turn."))
		"Keeper of the Flame":
			var burn := DamageEffect.new(2)
			burn.target_spec = KeeperSlot.keeper_spec(_more_life, "target opponent who has more life than you")
			c.activated(ActivatedAbility.new("{R}", true, [burn],
				"{R}, {T}: Choose target opponent who has more life than you do as you activate this ability. This creature deals 2 damage to that player."))
		"Mage il-Vec":
			c.activated(ActivatedAbility.new("", true, [DamageEffect.new(1).any_target()],
				"{T}, Discard a card at random: This creature deals 1 damage to any target.").with_random_discard_cost(1))
		"Ogre Shaman":
			c.activated(ActivatedAbility.new("{2}", false, [DamageEffect.new(2).any_target()],
				"{2}, Discard a card at random: This creature deals 2 damage to any target.").with_random_discard_cost(1))
		# ---------------------------------------------------------- green
		"Keeper of the Beasts":
			c.activated(ActivatedAbility.new("{G}", true,
				[KeeperSlot.new(_more_creatures, "target opponent who controls more creatures than you"),
					CreateTokenEffect.new("Beast", 2, 2, Mtg.ManaColor.G, "beast")],
				"{G}, {T}: Choose target opponent who controls more creatures than you do as you activate this ability. Create a 2/2 green Beast creature token."))
		"Plated Rootwalla":
			c.activated(ActivatedAbility.new("{2}{G}", false, [PumpEffect.new(3, 3).self_buff()],
				"{2}{G}: This creature gets +3/+3 until end of turn. Activate only once each turn.").per_turn(1))
		"Rootwater Alligator":
			# A regeneration effect: usable in the 1997 regeneration window.
			c.activated(ActivatedAbility.new("", false, [RegenerateEffect.new()],
				"Sacrifice a Forest: Regenerate this creature.").with_sacrifice_of("Forest", _forest))
		"Skyshroud Elite":
			c.static_ability(StaticAbility.new(_elite,
				"This creature gets +1/+2 as long as an opponent controls a nonbasic land."))
		"Skyshroud War Beast":
			c.as_it_enters(_choose_opponent)
			c.static_ability(StaticAbility.new(_war_beast_size,
				"Skyshroud War Beast's power and toughness are each equal to the number of nonbasic lands the chosen player controls.").setting_base_pt())
		_: return false
	return true


# ------------------------------------------------------------- filters --

static func _nonblack(i: CardInstance) -> bool:
	return (i.cur_colors & Mtg.ManaColor.B) == 0

static func _forest(i: CardInstance) -> bool:
	return i.is_land() and i.has_subtype("forest")

## A card in a hand has only its printed characteristics.
static func _creature_card(i: CardInstance) -> bool:
	return i.data.is_creature()

static func _nonbasic_land(i: CardInstance) -> bool:
	return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) == 0

## "With mana value X": the X being proposed while the target is chosen,
## the paid X on resolution ([method MtgGame.casting_x]).
static func _mana_value_x(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return i.data.cost.mana_value() == g.casting_x(s)

## Keeper of the Dead's creature: controlled by the player the first slot
## named — judged again on resolution (CR 608.2b).
static func _that_players(g: MtgGame, _s: CardInstance, candidate: TargetRef, earlier: Array) -> bool:
	if earlier.is_empty() or candidate.is_player or not (earlier[0] as TargetRef).is_player:
		return false
	var i := g.find_instance(candidate.instance_id)
	return i != null and i.controller_id == (earlier[0] as TargetRef).player_id


# ------------------------------------------------------- the Keepers --

## The Keepers' comparisons: [param them] is the candidate opponent,
## [param me] the activating player.
static func _more_life(g: MtgGame, them: int, me: int) -> bool:
	return g.players[them].life > g.players[me].life

static func _two_more_cards(g: MtgGame, them: int, me: int) -> bool:
	return g.players[them].hand.size() >= g.players[me].hand.size() + 2

static func _more_creatures(g: MtgGame, them: int, me: int) -> bool:
	return _creature_count(g, them) > _creature_count(g, me)

static func _two_fewer_creature_cards(g: MtgGame, them: int, me: int) -> bool:
	return _graveyard_creatures(g, them) + 2 <= _graveyard_creatures(g, me)

static func _creature_count(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_creature() and g.is_present(i): n += 1
	return n

static func _graveyard_creatures(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].graveyard:
		if i.data.is_creature(): n += 1
	return n


# ------------------------------------------------------------- statics --

## "You" off the battlefield is the card's owner (CR 604.3).
static func _chosen(g: MtgGame, s: CardInstance) -> int:
	var you := s.controller_id if s.zone == Mtg.Zone.BATTLEFIELD else s.owner_id
	var who := int(s.memory.get("chosen_player", g.opponent_of(you)))
	return who if who >= 0 and who < g.players.size() else g.opponent_of(you)

static func _specter_size(g: MtgGame, s: CardInstance) -> void:
	var n := g.players[_chosen(g, s)].hand.size()
	s.cur_power = n
	s.cur_toughness = n

static func _war_beast_size(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in g.players[_chosen(g, s)].battlefield:
		if _nonbasic_land(i) and g.is_present(i): n += 1
	s.cur_power = n
	s.cur_toughness = n

static func _elite(g: MtgGame, s: CardInstance) -> void:
	for p in g.players:
		if p.id == s.controller_id: continue
		for i in p.battlefield:
			if _nonbasic_land(i) and g.is_present(i):
				s.cur_power += 1
				s.cur_toughness += 2
				return

## "As this creature enters, choose an opponent" (CR 614.12) — journaled,
## as Haunting Apparition's (an arrival by another card's resolution is not
## covered by the card's own resolution record).
static func _choose_opponent(g: MtgGame, s: CardInstance, pid: int) -> void:
	var chosen := g.choose_opponent(pid, s)
	g._rec(s, &"memory")
	s.memory["chosen_player"] = chosen
	g.log_line("%s: %s chooses %s" % [s.data.card_name, g.players[pid].player_name, g.players[chosen].player_name])


# ------------------------------------------------------------ triggers --

static func _damages_a_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and int(e.data.get("amount", 0)) > 0 and e.data.has("to_player")

## "That player discards a card" — of their own choice; the trigger
## resolves even when the Specter has left (CR 603.6, 608.2h).
static func _specter_discard(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("to_player", -1))
	if who < 0 or who >= g.players.size(): return
	discard_one(g, who)

## [param who] discards one card of their choice (the DecisionAgent's
## discard funnel; a stray answer becomes the newest card in hand).
static func discard_one(g: MtgGame, who: int) -> void:
	var hand := g.players[who].hand
	if hand.is_empty(): return
	var picked := g.agents[who].choose_discard(g, who, 1)
	var thrown: Array[CardInstance] = [hand[hand.size() - 1]]
	if picked.size() == 1 and hand.has(picked[0]): thrown[0] = picked[0]
	g.discard_cards(who, thrown)


# ------------------------------------------------------------- actions --

static func _self_to_hand(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MA.same_activation(g, s):
		g.return_to_hand(s)

static func _self_to_library_top(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if MA.same_activation(g, s):
		g.return_permanent_to_library_top(s)


# ============================================================ effects ==

## A Keeper's "choose target opponent who … as you activate this ability".
## The slot itself does nothing; the ability's other effect acts.
class KeeperSlot extends EffectBase:
	var line: String
	func _init(measure: Callable, desc: String) -> void:
		target_spec = keeper_spec(measure, desc)
		line = "choose " + desc
		# The fair AI's reading (engine/ai/tempest_tactics.gd): a condition
		# slot — the ability is worth its NEXT effect, and only while some
		# opponent qualifies.
		ai_role = &"keeper_condition"
	## "Target opponent who …": [param measure] `func(game, them, me) ->
	## bool` compares the candidate with the activating player.
	static func keeper_spec(measure: Callable, desc: String) -> TargetSpec:
		var spec := TargetSpec.opponent().with_player_source_filter(_qualifies.bind(measure))
		spec.description = desc
		return spec
	## Judged as the ability is activated; once it resolves the comparison
	## is the past ("as you activate"), so only the rest of the target's
	## legality is checked again (CR 608.2b).
	static func _qualifies(g: MtgGame, them: int, s: CardInstance, measure: Callable) -> bool:
		if s == null: return false
		if g.current_resolution_controller() >= 0 and g.current_resolution_source() == s.data.card_name:
			return true
		var me := g.controller_acting_for(s)
		if me < 0 or me == them: return false
		return bool(measure.call(g, them, me))
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return line


## Furnace Brood: "Target creature can't be regenerated this turn"
## (CR 701.15d) — journaled, cleared at cleanup.
class NoRegeneration extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g._rec(i, &"regeneration_banned_this_turn")
		i.regeneration_banned_this_turn = true
		g.log_line("%s can't be regenerated this turn" % i.data.card_name, i)
	func describe() -> String:
		return "target creature can't be regenerated this turn"


## Rootwater Mystic: the activating player alone sees the top card of the
## target player's library (the array's end); nothing moves.
class LibraryPeek extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var library := g.players[t.player_id].library
		if library.is_empty(): return
		var top: CardInstance = library[library.size() - 1]
		g.reveal_information(pid, "Rootwater Mystic — top of %s's library" % g.players[t.player_id].player_name,
			[top.data.card_name])
		g.log_line("%s looks at the top card of %s's library" % [g.players[pid].player_name,
			g.players[t.player_id].player_name])
	func describe() -> String:
		return "look at the top card of target player's library"


## Thrull Surgeon: the ACTIVATING player looks at the target player's hand
## (shown to them alone) and chooses the card; that player discards it.
## A ChosenDiscardEffect, so the fair AI reads it as an aimed discard.
class SurgeonDiscard extends ChosenDiscardEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		var hand: Array[CardInstance] = g.players[who].hand.duplicate()
		var names: Array = []
		for i in hand: names.append(i.data.card_name)
		g.reveal_information(pid, "Thrull Surgeon — %s's hand" % g.players[who].player_name, names)
		if hand.is_empty(): return
		# Ranked for the chooser: the costliest card first (the funnel's
		# default for a hand), so a heuristic seat takes the best card.
		hand.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var card := g.agents[pid].choose_card(g, pid, hand,
			"Thrull Surgeon: choose a card from %s's hand to discard" % g.players[who].player_name, false, false, true)
		if card == null or not hand.has(card): card = hand[0]
		g.discard_cards(who, [card])
	func describe() -> String:
		return "target player discards a card you choose from their hand"
