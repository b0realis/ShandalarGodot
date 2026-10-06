extends RefCounted
## Exodus (_choices, Pack 9). Choices on entry or resolution: colours, players, card names, hidden-zone picks.
##
## THE OATHS. "At the beginning of each player's upkeep, that player
## chooses target player who <has more X> than they do and is their
## opponent. The first player may <do Y>." One upkeep trigger per Oath,
## heard at EVERY player's upkeep; its controller is the Oath's, but "that
## player" — the one whose upkeep it is — chooses the target
## (TriggeredAbility.chosen_by) and answers the "may" (CR 603.3d, 608.2d).
## The target requirement is a player filter judged against the upkeep's
## player, so with no qualifying opponent the trigger has no legal target
## and is removed from the stack (CR 603.3d), and an opponent who no longer
## qualifies when it resolves makes it fizzle (CR 608.2b). With two seats
## the target is forced.
##
## Mogg Assassin: two target slots — the activator's "target creature an
## opponent controls" and the opponent's "target creature"
## (TargetSpec.opponent_chooses, CR 601.2c) — and an untargeted third
## effect that flips the coin and destroys the creature the flip names, if
## that target is still legal (CR 608.2b: the ability does what it can).
##
## tests/cards/test_pack_9_B12_choices.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Mogg Assassin":
			var mine := AssassinMark.new(TargetSpec.creature("target creature an opponent controls") \
				.with_source_filter(_opponent_controls).because("controller"))
			var theirs := AssassinMark.new(TargetSpec.creature("target creature of an opponent's choice") \
				.opponent_chooses(_opponent_pick_first, "Select target creature."))
			c.activated(ActivatedAbility.new("", true, [mine, theirs, AssassinCoin.new(mine.target_spec, theirs.target_spec)],
				"{T}: You choose target creature an opponent controls, and that opponent chooses target creature. Flip a coin. If you win the flip, destroy the creature you chose. If you lose the flip, destroy the creature your opponent chose."))
		"Oath of Druids":
			_oath(c, _creatures, _druids,
				"At the beginning of each player's upkeep, that player chooses target player who controls more creatures than they do and is their opponent. The first player may reveal cards from the top of their library until they reveal a creature card. If the first player does, that player puts that card onto the battlefield and all other cards revealed this way into their graveyard.",
				"target player who controls more creatures than you and is your opponent")
		"Oath of Ghouls":
			_oath(c, _graveyard_creatures, _ghouls,
				"At the beginning of each player's upkeep, that player chooses target player whose graveyard has fewer creature cards in it than their graveyard does and is their opponent. The first player may return a creature card from their graveyard to their hand.",
				"target player whose graveyard has fewer creature cards than yours and is your opponent", true)
		"Oath of Lieges":
			_oath(c, _lands, _lieges,
				"At the beginning of each player's upkeep, that player chooses target player who controls more lands than they do and is their opponent. The first player may search their library for a basic land card, put that card onto the battlefield, then shuffle.",
				"target player who controls more lands than you and is your opponent")
		"Oath of Mages":
			_oath(c, _life, _mages,
				"At the beginning of each player's upkeep, that player chooses target player who has more life than they do and is their opponent. The first player may have this enchantment deal 1 damage to the second player.",
				"target player who has more life than you and is your opponent")
		"Oath of Scholars":
			_oath(c, _hand_size, _scholars,
				"At the beginning of each player's upkeep, that player chooses target player who has more cards in hand than they do and is their opponent. The first player may discard their hand and draw three cards.",
				"target player who has more cards in hand than you and is your opponent")
		_: return false
	return true


# ------------------------------------------------------------------ Oaths --

## Build one Oath: [param measure] `func(game, pid) -> int` is the compared
## quantity; the target must have MORE of it than the upkeep's player (or,
## with [param fewer], fewer — Oath of Ghouls compares the other way).
static func _oath(c: CardData, measure: Callable, action: Callable, text: String,
		desc: String, fewer := false) -> void:
	var spec := TargetSpec.player().with_player_filter(_oath_target.bind(measure, fewer))
	spec.description = desc
	var oath := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _oath_resolve.bind(action), text, _always) \
		.targeting(spec, Callable(), "Select %s." % desc) \
		.chosen_by(_upkeep_player)
	# The fair AI's shape (the Pack 9 bug pass, h6-3; engine/ai/tempest_spells.gd
	# `oath_choice`): the compared public quantity, so the caster can tell
	# whose upkeeps the Oath will serve. Set as the trigger's metadata — a
	# trigger has no effect list to carry an EffectBase role.
	oath.set_meta(&"ai_role", &"oath")
	oath.set_meta(&"ai_parameters", {"measure": measure, "fewer": fewer})
	c.triggered(oath)

static func _always(_g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool: return true

## "That player" chooses: the player whose upkeep it is.
static func _upkeep_player(_g: MtgGame, _s: CardInstance, e: GameEvent) -> int:
	return int(e.data.get("player", -1))

## The requirement, judged against the player whose upkeep it is — the
## active player while the trigger is put on the stack and as it resolves
## (CR 503.1, 608.2b): an opponent of theirs with more of the measure.
static func _oath_target(g: MtgGame, pid: int, measure: Callable, fewer: bool) -> bool:
	var first := g.active_player
	if pid == first or pid < 0 or first < 0: return false
	var theirs := int(measure.call(g, pid))
	var mine := int(measure.call(g, first))
	return theirs < mine if fewer else theirs > mine

static func _oath_resolve(g: MtgGame, s: CardInstance, e: GameEvent, action: Callable) -> void:
	var first := int(e.data.get("player", g.active_player))
	var ref := g.current_trigger_target(0)
	if ref == null or not ref.is_player: return
	action.call(g, s, first, ref.player_id)

static func _creatures(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_creature(): n += 1
	return n

static func _lands(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): n += 1
	return n

static func _graveyard_creatures(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].graveyard:
		if i.data.is_creature(): n += 1
	return n

static func _life(g: MtgGame, pid: int) -> int: return g.players[pid].life
static func _hand_size(g: MtgGame, pid: int) -> int: return g.players[pid].hand.size()

## Oath of Druids: reveal until a creature card; it goes onto the
## battlefield under the first player's control and every other revealed
## card into the graveyard — all of them when no creature card turns up.
## Hint, fair information only (docs/fair-play.md): accept while the first
## player's own DECKLIST still has a creature card unaccounted for by the
## zones they can see — never the library's order or its hidden contents.
static func _druids(g: MtgGame, _s: CardInstance, first: int, _second: int) -> void:
	var library := g.players[first].library
	var stocked := not library.is_empty() and _creature_cards_unseen(g, first) > 0
	if not g.agents[first].choose_yes_no(g, first,
			"Oath of Druids: reveal cards from the top of your library until you reveal a creature card?", stocked):
		return
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if card.data.is_creature():
			found = card
			break
	var names: Array = []
	for card in revealed: names.append(card.data.card_name)
	g.reveal_information(-1, "Oath of Druids reveals", names)
	g.log_line("%s reveals %s (Oath of Druids)" % [g.players[first].player_name, ", ".join(PackedStringArray(names))])
	if found != null:
		g.put_library_card_onto_battlefield(found, first)
	for card in revealed:
		if card != found: g.put_library_card_into_graveyard(card)

## Creature cards of [param pid]'s registered decklist not accounted for by
## a zone they can see (their hand; every battlefield, graveyard, exile and
## the ante, face-up cards they own) — the leg/petra_sphinx.gd accounting.
## No decklist (a bare game): nothing can be said without reading the
## hidden library, so the answer is "maybe one" — the hint accepts.
static func _creature_cards_unseen(g: MtgGame, pid: int) -> int:
	var p := g.players[pid]
	if p.deck_names.is_empty():
		return 1
	var left := {}
	for card_name in p.deck_names:
		var data := CardRegistry.get_card(card_name)
		if data != null and data.is_creature(): left[card_name] = int(left.get(card_name, 0)) + 1
	var known: Array = p.hand.duplicate()
	for player in g.players:
		for zone in [player.battlefield, player.graveyard, player.exile, player.ante]:
			for inst in zone:
				if not inst.face_down: known.append(inst)
	for inst in known:
		if inst.is_token or inst.owner_id != pid: continue
		var card_name: String = inst.data.card_name
		if left.has(card_name): left[card_name] = maxi(int(left[card_name]) - 1, 0)
	var total := 0
	for card_name in left: total += int(left[card_name])
	return total

## Oath of Ghouls: "may return a creature card" — the choice is optional.
static func _ghouls(g: MtgGame, _s: CardInstance, first: int, _second: int) -> void:
	var cards: Array[CardInstance] = []
	for i in g.players[first].graveyard:
		if i.data.is_creature(): cards.append(i)
	if cards.is_empty(): return
	var pick := g.agents[first].choose_card(g, first, cards,
		"Oath of Ghouls: return a creature card from your graveyard to your hand?", true)
	if pick != null and cards.has(pick):
		g.return_from_graveyard_to_hand(pick)

## Oath of Lieges: the search is the "may"; a declined search is no search
## (and no shuffle). A search that finds nothing still shuffles.
static func _lieges(g: MtgGame, _s: CardInstance, first: int, _second: int) -> void:
	if not g.agents[first].choose_yes_no(g, first,
			"Oath of Lieges: search your library for a basic land card and put it onto the battlefield?", true):
		return
	g.search_library(first, _basic_land, "Search your library for a basic land card", true)

static func _basic_land(i: CardInstance) -> bool:
	return i.data.is_land() and (i.data.supertypes & Mtg.Supertype.BASIC) != 0

## Oath of Mages: the Oath deals the damage — as it last existed if it has
## left (CR 608.2h) — to the target, the second player.
static func _mages(g: MtgGame, s: CardInstance, first: int, second: int) -> void:
	if g.agents[first].choose_yes_no(g, first,
			"Oath of Mages: have it deal 1 damage to %s?" % g.players[second].player_name, true):
		g.deal_damage(s, TargetRef.player(second), 1)

## Oath of Scholars. Hint: a new hand of three is worth it while the hand
## is no bigger than two cards (the hand the first player holds is theirs
## to see).
static func _scholars(g: MtgGame, _s: CardInstance, first: int, _second: int) -> void:
	var hint := g.players[first].hand.size() <= 2 and g.players[first].library.size() > 3
	if not g.agents[first].choose_yes_no(g, first,
			"Oath of Scholars: discard your hand and draw three cards?", hint):
		return
	g.discard_hand(first)
	g.draw_cards(first, 3)


# ------------------------------------------------------------ Mogg Assassin --

static func _opponent_controls(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and i.controller_id != g.controller_acting_for(s)

## The opponent's candidates, best first FOR THE OPPONENT: the creature
## their pick destroys only on the activator's lost flip, so the
## activator's most valuable creature first (the Assassin is one of them),
## then their own, the cheapest first. Public board only.
static func _opponent_pick_first(g: MtgGame, source: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var sa := _pick_score(g, source, a)
	var sb := _pick_score(g, source, b)
	if sa != sb: return sa > sb
	return a.instance_id < b.instance_id

static func _pick_score(g: MtgGame, source: CardInstance, ref: TargetRef) -> int:
	var i := g.find_instance(ref.instance_id)
	if i == null or source == null: return -100000
	var worth := maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0) + i.data.cost.mana_value()
	if i.controller_id == g.controller_acting_for(source): return 1000 + worth
	return -worth

## One of the Assassin's two named creatures. It destroys nothing on its
## own — the coin does — but it IS removal for the readers of the effect
## list (EffectIntent), which is what the activator's target pick needs.
class AssassinMark extends DestroyEffect:
	func _init(spec: TargetSpec) -> void:
		super(spec)
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "names %s" % target_spec.description

## The flip and the destruction. The two refs are the ability's slots in
## order (MtgGame.current_targets); each is re-judged here, so a creature
## that left, gained shroud or changed controller is not destroyed.
class AssassinCoin extends EffectBase:
	var mine_spec: TargetSpec
	var theirs_spec: TargetSpec
	func _init(mine: TargetSpec, theirs: TargetSpec) -> void:
		mine_spec = mine
		theirs_spec = theirs
		# The AI's shape (Pack 9 stage 4): a coin between the activator's
		# pick and the opponent's (engine/ai/tempest_spells.gd).
		with_ai_role(&"coin_destroy_either")
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var refs := g.current_targets()
		var won := g.flip_coin(pid)
		var slot := 0 if won else 1
		if refs.size() <= slot or refs[slot] == null: return
		var spec := mine_spec if won else theirs_spec
		var earlier: Array = [] if slot == 0 else [refs[0]]
		if not spec.is_legal(g, refs[slot], s, earlier, pid):
			g.log_line("Mogg Assassin: the creature the flip names is no longer a legal target")
			return
		var victim := g.find_instance(refs[slot].instance_id)
		if g.is_present(victim): g.destroy(victim)
	func describe() -> String:
		return "flip a coin; destroy your choice on a win, your opponent's on a loss"
