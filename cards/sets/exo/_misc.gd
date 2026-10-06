extends RefCounted
## Exodus (_misc, Pack 9). Everything else: global effects and one-off rules.
##
## - Cataclysm / Limited Resources: every player chooses in APNAP order
##   (CR 101.4) through their own DecisionAgent, then everything not chosen
##   is sacrificed at once (one simultaneous event, CR 704.3). Cataclysm's
##   four picks are each from the permanents of that type, so an artifact
##   creature may be the choice for both types (it is "an artifact" and "a
##   creature"), and a type a player has none of is simply not chosen.
## - Limited Resources' land ban is a play ban (CardData.bans_playing): it
##   stops PLAYING lands (CR 305.1), never putting one onto the battlefield.
## - Song of Serenity reads "enchanted" live (MtgGame.is_enchanted).
## - Volrath's Dungeon's "Pay 5 life: destroy" is ANY player's, only during
##   their own turn (activator_condition); its discard ability is its
##   controller's, at sorcery speed.
## tests/cards/test_pack_9_B12_misc.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")

const CATACLYSM_TYPES := [Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE,
	Mtg.CardType.ENCHANTMENT, Mtg.CardType.LAND]
const CATACLYSM_WORDS := ["an artifact", "a creature", "an enchantment", "a land"]

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Cataclysm":
			c.spell(F.Action.new(_cataclysm,
				"each player chooses an artifact, a creature, an enchantment and a land they control, then sacrifices the rest") \
				.with_ai_role(&"cataclysm"))
		"Limited Resources":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _limited_resources,
				"When this enchantment enters, each player chooses five lands they control and sacrifices the rest.", F._self_enter))
			c.bans_playing(_ten_lands_out)
		"Mind Over Matter":
			c.activated(ActivatedAbility.new("", false, [TapOrUntap.new()],
				"Discard a card: You may tap or untap target artifact, creature, or land.").with_discard_cost(1))
		"Peace of Mind":
			c.activated(ActivatedAbility.new("{W}", false, [GainLifeEffect.new(3)],
				"{W}, Discard a card: You gain 3 life.").with_discard_cost(1))
		"Recurring Nightmare":
			c.activated(ActivatedAbility.new("", false, [ReturnFromGraveyardEffect.new().to_battlefield()],
				"Sacrifice a creature, Return this enchantment to its owner's hand: Return target creature card from your graveyard to the battlefield. Activate only as a sorcery.") \
				.with_sacrifice_of("creature", _creature).with_return_cost().only_if(MA.sorcery_speed))
		"Seismic Assault":
			var blast := ActivatedAbility.new("", false, [DamageEffect.new(2).any_target()],
				"Discard a land card: This enchantment deals 2 damage to any target.").with_discard_cost(1)
			blast.discard_filter = _land_card
			blast.discard_filter_desc = "land card"
			c.activated(blast)
		"Song of Serenity":
			c.static_ability(StaticAbility.new(_serenity, "Creatures that are enchanted can't attack or block."))
		"Survival of the Fittest":
			var tutor := ActivatedAbility.new("{G}", false, [RevealedCreatureSearch.new()],
				"{G}, Discard a creature card: Search your library for a creature card, reveal that card, put it into your hand, then shuffle.") \
				.with_discard_cost(1)
			tutor.discard_filter = _creature_card
			tutor.discard_filter_desc = "creature card"
			c.activated(tutor)
		"Treasure Trove":
			c.activated(ActivatedAbility.new("{2}{U}{U}", false, [DrawEffect.new(1)], "{2}{U}{U}: Draw a card."))
		"Volrath's Dungeon":
			var breakout := ActivatedAbility.new("", false,
				[F.Action.new(_dungeon_destroyed, "destroy this enchantment").with_ai_role(&"destroy_source_for_life", {"life": 5})],
				"Pay 5 life: Destroy this enchantment. Any player may activate this ability but only during their turn.") \
				.with_life_cost(5).anyone_activated()
			breakout.activator_condition = _on_your_turn
			c.activated(breakout)
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_dungeon_top, "target player puts a card from their hand on top of their library", TargetSpec.player()) \
					.with_ai_role(&"hand_to_library_top")],
				"Discard a card: Target player puts a card from their hand on top of their library. Activate only as a sorcery.") \
				.with_discard_cost(1).only_if(MA.sorcery_speed))
		_: return false
	return true


static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()
static func _land_card(i: CardInstance) -> bool: return i.data.is_land()
static func _anything(_i: CardInstance) -> bool: return true

## APNAP order (CR 101.4): the active player first.
static func _apnap(g: MtgGame) -> Array[int]:
	var out: Array[int] = []
	for k in g.players.size():
		out.append((g.active_player + k) % g.players.size())
	return out

## A rough public worth for a pick hint: mana value plus a creature's body.
static func _worth(i: CardInstance) -> int:
	var w := i.data.cost.mana_value()
	if i.is_creature(): w += maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0)
	if i.is_land(): w += 2 + (0 if (i.data.supertypes & Mtg.Supertype.BASIC) != 0 else 1)
	return w


# --------------------------------------------------------------- Cataclysm --

## Each player, active player first, picks one permanent of each of the
## four types from among those they control (a type they have none of
## takes no pick); then every permanent of every player that was not
## picked is sacrificed in one event. The hint offers the most valuable
## permanent not already kept first, so a heuristic seat never spends two
## picks on one artifact creature while another creature waits.
static func _cataclysm(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var kept := {}
	for who in _apnap(g):
		for n in CATACLYSM_TYPES.size():
			var cards: Array[CardInstance] = []
			for i in g.players[who].battlefield:
				if i.is_type(CATACLYSM_TYPES[n]): cards.append(i)
			if cards.is_empty(): continue
			cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
				var ka := kept.has(a.id)
				var kb := kept.has(b.id)
				if ka != kb: return kb
				var wa := _worth(a)
				var wb := _worth(b)
				return wa > wb if wa != wb else a.id < b.id)
			var pick := g.agents[who].choose_card(g, who, cards,
				"Cataclysm: choose %s to keep" % CATACLYSM_WORDS[n], false, false, true)
			if pick == null or not cards.has(pick): pick = cards[0]
			kept[pick.id] = true
	var doomed: Array[CardInstance] = []
	for who in _apnap(g):
		for i in g.players[who].battlefield:
			if not kept.has(i.id): doomed.append(i)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed:
		if g.is_present(i): g.sacrifice_permanent(i)
	g.end_simultaneous()


# ------------------------------------------------------- Limited Resources --

static func _limited_resources(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var doomed: Array[CardInstance] = []
	for who in _apnap(g):
		var lands: Array[CardInstance] = []
		for i in g.players[who].battlefield:
			if i.is_land(): lands.append(i)
		if lands.size() <= 5: continue
		lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var wa := _worth(a)
			var wb := _worth(b)
			return wa > wb if wa != wb else a.id < b.id)
		var keep: Array[CardInstance] = []
		while keep.size() < 5:
			var left: Array[CardInstance] = []
			for i in lands:
				if not keep.has(i): left.append(i)
			var pick := g.agents[who].choose_card(g, who, left,
				"Limited Resources: choose a land to keep (%d of 5)" % (keep.size() + 1), false, false, true)
			if pick == null or not left.has(pick): pick = left[0]
			keep.append(pick)
		for i in lands:
			if not keep.has(i): doomed.append(i)
	if doomed.is_empty(): return
	g.begin_simultaneous()
	for i in doomed:
		if g.is_present(i): g.sacrifice_permanent(i)
	g.end_simultaneous()

## "Players can't play lands as long as ten or more lands are on the
## battlefield." Counted live, every player's lands together.
static func _ten_lands_out(g: MtgGame, _pid: int, data: CardData) -> bool:
	if not data.is_land(): return false
	var n := 0
	for i in g.all_battlefield():
		if i.is_land(): n += 1
	return n >= 10


# --------------------------------------------------------- Mind Over Matter --

## "You may tap or untap target artifact, creature, or land" — Twiddle's
## choice, with "neither" for the "may". A TapEffect so the AI's readers see
## its usual use (tapping a threat).
class TapOrUntap extends TapEffect:
	const MODES: Array[String] = ["Tap it", "Untap it", "Leave it as it is"]
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", _valid))
	static func _valid(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		# Hint: untap our own tapped permanent, tap theirs, else leave it.
		var mine := i.controller_id == pid
		var hint := 2
		if mine and i.tapped: hint = 1
		elif not mine and not i.tapped: hint = 0
		var mode: int = g.agents[pid].choose_option(g, pid, MODES,
			"%s: tap or untap %s?" % [s.data.card_name, i.data.card_name], hint)
		if mode == 0: g.tap_permanent(i)
		elif mode == 1: g.untap_permanent(i)
	func describe() -> String:
		return "you may tap or untap target artifact, creature, or land"


# --------------------------------------------------------- Song of Serenity --

static func _serenity(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and g.is_enchanted(i):
			i.cur_cant_attack = true
			i.cur_cant_block_filter = _anything


# -------------------------------------------------- Survival of the Fittest --

## "Search your library for a creature card, reveal that card, put it into
## your hand, then shuffle." A legal search shows the searcher their whole
## library (CR 701.19b); the found card is revealed to the table.
class RevealedCreatureSearch extends SearchLibraryEffect:
	func _init() -> void:
		super("a creature card", _creature_card)
	static func _creature_card(i: CardInstance) -> bool: return i.data.is_creature()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.search_library(pid, filter, "Search your library for a creature card", false, true,
			"Survival of the Fittest — revealed")


# --------------------------------------------------------- Volrath's Dungeon --

static func _on_your_turn(g: MtgGame, _s: CardInstance, pid: int) -> String:
	return "" if g.active_player == pid else "activate only during your turn"

static func _dungeon_destroyed(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s): g.destroy(s)

## The TARGET player chooses which card of their own hand goes on top.
static func _dungeon_top(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var who := t.player_id
	var hand: Array[CardInstance] = g.players[who].hand.duplicate()
	if hand.is_empty(): return
	var card := g.agents[who].choose_card(g, who, hand,
		"%s: put a card from your hand on top of your library" % s.data.card_name, false)
	if card == null or not hand.has(card): card = hand[0]
	g.put_from_hand_on_top_of_library(card)
