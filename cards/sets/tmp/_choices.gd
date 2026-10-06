extends RefCounted
## Tempest (_choices, Pack 9). Choices on entry or resolution: colours,
## players, card names, hidden-zone picks.
##
## Every choice is asked of the seat the card names, through its
## DecisionAgent funnel (choose_card / choose_option / choose_yes_no /
## choose_number), so the pre-flight holds a human seat; each hint is
## computed from what that seat may know (docs/fair-play.md) — the public
## board, its own hand and decklist, and the cards the effect itself shows
## it — never an unseen library order or the other hand.
##
## - "Any number of" is one yes/no per candidate (Ancestral Knowledge's
##   shape, wth/_costs.gd) or a count per card name (Mana Severance), so a
##   seat's hint can stop anywhere; an "in any order" put-back asks one
##   card at a time, the first answer ending on top (choose_card_in_order).
## - Opponent-chooses (Intuition, Phyrexian Grimoire, Oracle en-Vec) goes
##   to the TARGET opponent's agent, the candidates ranked from THAT seat's
##   side (`adverse`).
## - Card names (Wood Sage) come from the naming seat's own DECKLIST, each
##   once, most copies unaccounted for first — the owner's ruling of
##   2026-09-07 (leg/petra_sphinx.gd: RiddleEffect.nameable). Lobotomy
##   names nothing: it picks from the revealed hand.
## - A library or hand searched for cards "with the same name" may fail to
##   find (CR 701.19b), so Lobotomy asks once before exiling from those two
##   hidden zones; the graveyard is public and gives up every copy.
## - Oracle en-Vec: the opponent answers at resolution; "during that
##   player's next turn" is MtgGame.queue_next_turn_static (the turn that
##   actually begins — a skipped one is not it, CR 614.10); "at the
##   beginning of that turn's end step" is a delayed trigger (CR 603.7)
##   for the first end step of that player's after this one, remembering
##   each chosen creature's battlefield incarnation (CR 400.7).
## - Reap's count is engine package E7's target_count_fn: X is fixed as
##   the spell is cast (CR 601.2c) from the target opponent's black
##   permanents then.
## - Scroll Rack exiles face down, then puts that many top cards into the
##   hand without drawing them (CR 121.8: no draw triggers, no draw
##   replacement, an empty library is no loss).
## tests/cards/test_pack_9_B6_choices.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const TYPES := preload("res://engine/core/creature_types.gd")
const NAMES := preload("res://cards/sets/leg/petra_sphinx.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Extinction": c.spell(Extinction.new())
		"Intuition": c.spell(Intuition.new())
		"Lobotomy":
			c.spell(F.Action.new(_lobotomy,
				"target player reveals their hand; you choose a card other than a basic land card from it and exile every card with that name from their graveyard, hand, and library; then they shuffle",
				TargetSpec.player()).with_ai_role(&"name_from_revealed_hand_exile_all"))
		"Mana Severance":
			c.spell(F.Action.new(_severance, "search your library for any number of land cards, exile them, then shuffle",
				null, true).with_ai_role(&"exile_lands_from_library"))
		"Mirri's Guile":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _guile,
				"At the beginning of your upkeep, you may look at the top three cards of your library, then put them back in any order.",
				F._your_upkeep))
		"Oracle en-Vec":
			c.activated(ActivatedAbility.new("", true, [F.Action.new(_oracle,
				"target opponent chooses any number of creatures they control; during that player's next turn the chosen creatures attack if able and other creatures can't attack; at that turn's end step, destroy each chosen creature that didn't attack",
				TargetSpec.opponent()).with_ai_role(&"forced_attack_order")],
				"{T}: Target opponent chooses any number of creatures they control. During that player's next turn, the chosen creatures attack if able, and other creatures can't attack. At the beginning of that turn's end step, destroy each of the chosen creatures that didn't attack this turn. Activate only during your turn.") \
				.your_turn_only())
		"Phyrexian Grimoire":
			c.activated(ActivatedAbility.new("{4}", true, [F.Action.new(_grimoire,
				"target opponent chooses one of the top two cards of your graveyard; exile that card and put the other one into your hand",
				TargetSpec.opponent()).with_ai_role(&"opponent_splits_graveyard_top_two")],
				"{4}, {T}: Target opponent chooses one of the top two cards of your graveyard. Exile that card and put the other one into your hand."))
		"Precognition":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _precognition,
				"At the beginning of your upkeep, you may look at the top card of target opponent's library. If you do, you may put that card on the bottom of that player's library.",
				F._your_upkeep).targeting(TargetSpec.opponent()))
		"Reap":
			c.spell(OpponentSlot.new())
			var cards := ReturnFromGraveyardEffect.new().any_card()
			cards.target_spec.description = "up to X target cards from your graveyard"
			cards.helpful()
			cards.targets_counted_by(_reap_count)
			c.spell(cards)
		"Sacred Guide":
			c.activated(ActivatedAbility.new("{1}{W}", false, [F.Action.new(_sacred_guide,
				"reveal cards from the top of your library until you reveal a white card; put that card into your hand and exile all other cards revealed this way",
				null, true)],
				"{1}{W}, Sacrifice this creature: Reveal cards from the top of your library until you reveal a white card. Put that card into your hand and exile all other cards revealed this way.") \
				.with_sacrifice_cost())
		"Scroll Rack":
			c.activated(ActivatedAbility.new("{1}", true, [F.Action.new(_scroll_rack,
				"exile any number of cards from your hand face down; put that many cards from the top of your library into your hand; then put the exiled cards on top of your library in any order",
				null, true).with_ai_role(&"hand_library_swap")],
				"{1}, {T}: Exile any number of cards from your hand face down. Put that many cards from the top of your library into your hand. Then look at the exiled cards and put them on top of your library in any order."))
		"Wood Sage":
			c.activated(ActivatedAbility.new("", true, [F.Action.new(_wood_sage,
				"choose a creature card name; reveal the top four cards of your library, put all of them with that name into your hand and the rest into your graveyard",
				null, true).with_ai_role(&"name_and_dig_four")],
				"{T}: Choose a creature card name. Reveal the top four cards of your library and put all of them with that name into your hand. Put the rest into your graveyard."))
		_: return false
	return true


# ================================================================== shared

## Helpers shared by the module's functions and its inner classes (an
## inner class reaches a sibling class by name).
class U:
	## A card's worth to whoever holds it — the hint for which card a seat
	## keeps, gives or puts back. Public facts only: its own costs and its
	## owner's land count on the battlefield.
	static func card_value(g: MtgGame, card: CardInstance) -> float:
		if card.data.is_land():
			return 3.5 if lands(g, card.owner_id) < 5 else 0.5
		return 2.0 + float(card.data.cost.mana_value())

	static func lands(g: MtgGame, pid: int) -> int:
		var n := 0
		for i in g.players[pid].battlefield:
			if i.is_land(): n += 1
		return n

	## [param cards] ranked by [method card_value], best first; ties by id
	## so the order never depends on where a card sits in a hidden zone.
	static func best_first(g: MtgGame, cards: Array[CardInstance]) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		out.assign(cards)
		out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			var va := U.card_value(g, a)
			var vb := U.card_value(g, b)
			if va != vb: return va > vb
			return a.id < b.id)
		return out

	static func names(cards: Array) -> Array:
		var out: Array = []
		for card in cards: out.append(card.data.card_name)
		return out

	static func who(g: MtgGame, pid: int) -> String:
		return g.players[pid].player_name

## The controller of the trigger resolving now ("you").
static func _resolving_pid(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id

## Ask [param pid] to order [param cards] from the top down, one card at a
## time; the first answer ends on top. Hint: best first.
static func _order_top(g: MtgGame, pid: int, cards: Array[CardInstance], prompt: String) -> Array[CardInstance]:
	var rest := U.best_first(g, cards)
	var ordered: Array[CardInstance] = []
	while rest.size() > 1:
		var next := g.agents[pid].choose_card_in_order(g, pid, rest, prompt)
		if next == null or not rest.has(next): next = rest[0]
		ordered.append(next)
		rest.erase(next)
	ordered.append_array(rest)
	return ordered


## "Target opponent" as a slot of its own (Reap counts against it).
class OpponentSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func describe() -> String:
		return "the opponent whose black permanents are counted"


# ============================================================== Extinction

## "Destroy all creatures of the creature type of your choice": the type is
## chosen as it resolves, from the whole catalogue (An-Zerrin Ruins'
## list, hml/_links.gd); every creature of that type then goes in one event
## (regeneration allowed). The hint is the type whose loss costs the other
## seat the most against ours, read off the public board. The AI's sweep
## reader sees a DestroyAllEffect with no filter — every creature — which
## undervalues a one-sided type and never overvalues the swing the hint
## then picks.
class Extinction extends DestroyAllEffect:
	func _init() -> void:
		super("all creatures of the creature type of your choice")
		with_ai_role(&"sweep_chosen_type")   # the AI's shape (Pack 9 stage 4)
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var pick := g.agents[pid].choose_option(g, pid, TYPES.ALL,
			"Extinction: choose a creature type", Extinction.hint(g, pid))
		var kind: String = TYPES.ALL[clampi(pick, 0, TYPES.ALL.size() - 1)].to_lower()
		g.log_line("%s chooses %s for %s" % [U.who(g, pid), kind.capitalize(), s.data.card_name])
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if i.is_creature() and g.is_present(i) and i.has_subtype(kind):
				victims.append(i)
		g.begin_simultaneous()
		for i in victims:
			g.destroy(i)
		g.end_simultaneous()
	static func hint(g: MtgGame, pid: int) -> int:
		var score := {}
		for i in g.all_battlefield():
			if not i.is_creature() or not g.is_present(i): continue
			var worth := 1 + i.data.cost.mana_value() + maxi(i.cur_power, 0) + maxi(i.cur_toughness, 0)
			for kind in i.cur_subtypes:
				score[kind] = int(score.get(kind, 0)) + (worth if i.controller_id != pid else -worth)
		var best := 0
		var top := 0
		for index in TYPES.ALL.size():
			var value := int(score.get(TYPES.ALL[index].to_lower(), 0))
			if value > top:
				top = value
				best = index
		return best
	func describe() -> String:
		return "destroy all creatures of the creature type of your choice"


# =============================================================== Intuition

## Three cards (as many as the library holds — a search for a number of
## cards with no stated quality finds that many if it can, CR 701.19b), all
## revealed; the TARGET opponent chooses the one that goes to the hand, the
## rest go to the graveyard, then the library is shuffled. A
## SearchLibraryEffect in the AI's eyes (a card off the library).
class Intuition extends SearchLibraryEffect:
	func _init() -> void:
		super("three cards")
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var library := g.players[pid].library
		var found: Array[CardInstance] = []
		for n in mini(3, library.size()):
			var candidates: Array[CardInstance] = []
			for card in library:
				if not found.has(card): candidates.append(card)
			candidates = U.best_first(g, candidates)
			var pick := g.agents[pid].choose_card(g, pid, candidates,
				"Intuition: choose a card to reveal (%d of 3)" % (n + 1), false, false, true)
			if pick == null or not candidates.has(pick): pick = candidates[0]
			found.append(pick)
		if found.is_empty():
			g.shuffle_library(pid)
			return
		g.reveal_information(-1, "Intuition reveals", U.names(found))
		g.log_line("%s reveals %s (Intuition)" % [U.who(g, pid), ", ".join(PackedStringArray(U.names(found)))])
		var opp := t.player_id
		# The opponent's own best answer first: the card worth the least to
		# the caster (adverse, PlayerChoice.adverse).
		var offered := U.best_first(g, found)
		offered.reverse()
		var given := g.agents[opp].choose_card(g, opp, offered,
			"Intuition: choose the card %s puts into their hand (the rest go to the graveyard)" % U.who(g, pid),
			false, true)
		if given == null or not offered.has(given): given = offered[0]
		g.log_line("%s chooses %s for %s's hand (%s)" % [U.who(g, opp), given.data.card_name, U.who(g, pid),
			s.data.card_name])
		g.library_card_to_hand(given)
		for card in found:
			if card != given: g.put_library_card_into_graveyard(card)
		g.shuffle_library(pid)
	func describe() -> String:
		return "search your library for three cards and reveal them; target opponent chooses one for your hand, the rest go to your graveyard; then shuffle"


# ================================================================ Lobotomy

static func _lobotomy(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var victim := t.player_id
	var hand: Array[CardInstance] = g.players[victim].hand.duplicate()
	g.reveal_information(-1, "Lobotomy — %s's hand" % U.who(g, victim), U.names(hand))
	g.log_line("%s reveals their hand: %s" % [U.who(g, victim), ", ".join(PackedStringArray(U.names(hand)))])
	var choices: Array[CardInstance] = []
	for card in hand:
		if not (card.data.is_land() and (card.data.supertypes & Mtg.Supertype.BASIC) != 0):
			choices.append(card)
	if not choices.is_empty():
		# Hint: against an opponent, their most valuable card; against
		# ourselves, the cheapest to lose.
		choices = U.best_first(g, choices)
		if victim == pid: choices.reverse()
		var pick := g.agents[pid].choose_card(g, pid, choices,
			"Lobotomy: choose a card other than a basic land card", false, false, true)
		if pick == null or not choices.has(pick): pick = choices[0]
		_extract(g, s, pid, victim, pick.data.card_name)
	g.shuffle_library(victim)

## Exile every card named [param named] the victim owns in their
## graveyard (public: every one), then — the searcher may fail to find in a
## hidden zone (CR 701.19b) — in their hand and library on a yes.
static func _extract(g: MtgGame, s: CardInstance, pid: int, victim: int, named: String) -> void:
	g.log_line("%s chooses %s (%s)" % [U.who(g, pid), named, s.data.card_name])
	var p := g.players[victim]
	for card in p.graveyard.duplicate():
		if card.data.card_name == named: g.exile_from_graveyard(card)
	var hidden: Array[CardInstance] = []
	for card in p.hand:
		if card.data.card_name == named: hidden.append(card)
	for card in p.library:
		if card.data.card_name == named: hidden.append(card)
	if hidden.is_empty():
		return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Lobotomy: exile the %d card(s) named %s in %s's hand and library?" % [hidden.size(), named, U.who(g, victim)],
			victim != pid):
		return
	for card in hidden:
		if card.zone == Mtg.Zone.HAND: g.exile_from_hand(card)
		elif card.zone == Mtg.Zone.LIBRARY: g.exile_library_card(card)


# ========================================================== Mana Severance

## One count per land name (basic lands of one name are interchangeable,
## so a seat is asked a handful of questions, not one per card). Hint:
## keep about six lands in sight — battlefield, hand and library together —
## and exile the rest.
static func _severance(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var by_name := {}
	for card in g.players[pid].library:
		if card.data.is_land():
			if not by_name.has(card.data.card_name): by_name[card.data.card_name] = []
			(by_name[card.data.card_name] as Array).append(card)
	var names: Array = by_name.keys()
	names.sort()
	var seen := U.lands(g, pid)
	for card in g.players[pid].hand:
		if card.data.is_land(): seen += 1
	var keep := maxi(0, 6 - seen)
	for name in names:
		var cards: Array = by_name[name]
		var stay := mini(keep, cards.size())
		keep -= stay
		var count := g.agents[pid].choose_number(g, pid, 0, cards.size(),
			"Mana Severance: how many %s to exile?" % name, cards.size() - stay)
		for n in clampi(count, 0, cards.size()):
			g.exile_library_card(cards[n])
	g.shuffle_library(pid)


# ============================================================ Mirri's Guile

static func _guile(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _resolving_pid(g, s)
	var library := g.players[pid].library
	var n := mini(3, library.size())
	if n == 0:
		return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Mirri's Guile: look at the top three cards of your library and put them back in any order?", true):
		return
	var seen: Array[CardInstance] = []
	for k in n: seen.append(library[library.size() - 1 - k])
	g.reveal_information(pid, "Mirri's Guile — the top %d card(s) of your library" % n, U.names(seen))
	g.reorder_top_of_library(pid, _order_top(g, pid, seen, "Mirri's Guile: choose the next card from the top"))


# ============================================================ Oracle en-Vec

## The opponent picks among the creatures they control as it resolves, one
## yes/no each. Hint, from their side and the public board: choose a
## creature that can attack and outlasts the activator's biggest striker
## (it survives any one block); the rest stay home safely.
static func _oracle(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var opp := t.player_id
	var threat := 0
	for i in g.players[pid].creatures(): threat = maxi(threat, i.cur_power)
	var chosen: Array = []
	var names: Array = []
	for body in g.players[opp].creatures():
		if not g.is_present(body): continue
		var hint := body.cur_power > 0 and not body.has_keyword(Mtg.Keyword.DEFENDER) and body.cur_toughness > threat
		if g.agents[opp].choose_yes_no(g, opp,
				"Oracle en-Vec: choose %s? Chosen creatures must attack during your next turn and are destroyed at its end step if they didn't; your other creatures can't attack." % body.data.card_name,
				hint):
			chosen.append([body.id, body.layer_timestamp])
			names.append(body.data.card_name)
	g.log_line("%s chooses %s (%s)" % [U.who(g, opp), ", ".join(PackedStringArray(names)) if not names.is_empty() else "no creatures",
		s.data.card_name])
	# An attack REQUIREMENT imposed by an effect, not an ability the creature
	# gains (CR 508.1d): deliberately NOT flagged changing_abilities(), so it
	# applies after layer 6 and a newer Humility cannot remove it — the shape
	# Taunt's next-turn static uses (por/_spells.gd _combat_rule).
	g.queue_next_turn_static(opp, s, StaticAbility.new(_oracle_rule.bind(chosen),
		"The chosen creatures attack this turn if able; other creatures can't attack."))
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _oracle_doom,
		"At the beginning of that turn's end step, destroy each of the chosen creatures that didn't attack this turn.",
		_oracle_end_step.bind(opp, g.turn_number)), pid, s, false, {"chosen": chosen})

static func _is_chosen(i: CardInstance, chosen: Array) -> bool:
	for row in chosen:
		if int(row[0]) == i.id and int(row[1]) == i.layer_timestamp: return true
	return false

static func _oracle_rule(g: MtgGame, _s: CardInstance, chosen: Array) -> void:
	for i in g.all_battlefield():
		if not i.is_creature(): continue
		if _is_chosen(i, chosen):
			if not i.cur_keywords.has(Mtg.Keyword.MUST_ATTACK): i.cur_keywords.append(Mtg.Keyword.MUST_ATTACK)
		else:
			i.cur_cant_attack = true

## That player's first end step after the activation: the activation is
## "only during your turn", so their next turn is the first of theirs to
## reach an end step (a skipped turn has none).
static func _oracle_end_step(g: MtgGame, _s: CardInstance, _e: GameEvent, opp: int, turn: int) -> bool:
	return g.active_player == opp and g.turn_number > turn

static func _oracle_doom(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var doomed: Array[CardInstance] = []
	for row in memory.get("chosen", []):
		var i := g.find_instance(int(row[0]))
		if g.is_present(i) and i.layer_timestamp == int(row[1]) and not i.attacked_this_turn:
			doomed.append(i)
	g.begin_simultaneous()
	for i in doomed:
		g.destroy(i)
	g.end_simultaneous()


# ======================================================= Phyrexian Grimoire

## The top of a graveyard is its back. The opponent's best answer first:
## the card worth more to the activator, which goes to exile.
static func _grimoire(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var grave := g.players[pid].graveyard
	if grave.is_empty():
		return
	var top: Array[CardInstance] = []
	for n in mini(2, grave.size()): top.append(grave[grave.size() - 1 - n])
	var opp := t.player_id
	var offered := U.best_first(g, top)
	var gone := g.agents[opp].choose_card(g, opp, offered,
		"Phyrexian Grimoire: choose the card to exile (the other goes to %s's hand)" % U.who(g, pid), false, true)
	if gone == null or not offered.has(gone): gone = offered[0]
	g.log_line("%s chooses %s to exile (%s)" % [U.who(g, opp), gone.data.card_name, s.data.card_name])
	g.exile_from_graveyard(gone)
	for card in top:
		if card != gone and card.zone == Mtg.Zone.GRAVEYARD: g.return_from_graveyard_to_hand(card)


# ============================================================ Precognition

## The look is the "may"; the bottom is a second "may", hinted from the
## card actually seen: a spell, or a land while its owner is short of them.
static func _precognition(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ref := g.current_trigger_target(0)
	if ref == null or not ref.is_player:
		return
	var pid := _resolving_pid(g, s)
	var opp := ref.player_id
	var library := g.players[opp].library
	if library.is_empty():
		return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Precognition: look at the top card of %s's library?" % U.who(g, opp), true):
		return
	var top: CardInstance = library.back()
	g.reveal_information(pid, "Precognition — the top card of %s's library" % U.who(g, opp), [top.data.card_name])
	var hint := U.card_value(g, top) >= 3.0
	if g.agents[pid].choose_yes_no(g, pid,
			"Precognition: put %s on the bottom of %s's library?" % [top.data.card_name, U.who(g, opp)], hint):
		g.put_on_bottom_of_library(top)
		g.log_line("%s puts the top card of %s's library on the bottom (Precognition)" % [U.who(g, pid), U.who(g, opp)])


# ==================================================================== Reap

## E7: X is the number of black permanents the target opponent controls
## as Reap is cast — "up to X" (CR 601.2c). A phased-out permanent is
## treated as though it does not exist (CR 702.26b).
static func _reap_count(g: MtgGame, _s: CardInstance, earlier: Array) -> Vector2i:
	if earlier.is_empty() or earlier[0] == null or not (earlier[0] as TargetRef).is_player:
		return Vector2i(0, 0)
	var n := 0
	for i in g.players[(earlier[0] as TargetRef).player_id].battlefield:
		if g.is_present(i) and (i.cur_colors & Mtg.ManaColor.B) != 0: n += 1
	return Vector2i(0, n)


# ============================================================ Sacred Guide

## Reveal until a white card (as printed in the library, CR 105.1); it goes
## to the hand, every other revealed card is exiled — the whole library
## when none is white. Stops at an empty library.
static func _sacred_guide(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	var found: CardInstance = null
	for n in range(library.size() - 1, -1, -1):
		var card: CardInstance = library[n]
		revealed.append(card)
		if (card.data.color_mask() & Mtg.ManaColor.W) != 0:
			found = card
			break
	if revealed.is_empty():
		return
	g.reveal_information(-1, "Sacred Guide reveals", U.names(revealed))
	g.log_line("%s reveals %s (Sacred Guide)" % [U.who(g, pid), ", ".join(PackedStringArray(U.names(revealed)))])
	if found != null:
		g.library_card_to_hand(found)
	for card in revealed:
		if card != found: g.exile_library_card(card)


# ============================================================= Scroll Rack

## One yes/no per card in hand. Hint: lands while three or more are already
## on the battlefield (they are the cards to swap away), nothing else.
static func _scroll_rack(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var swap_lands := U.lands(g, pid) >= 3 and not g.players[pid].library.is_empty()
	var chosen: Array[CardInstance] = []
	for card in g.players[pid].hand.duplicate():
		if g.agents[pid].choose_yes_no(g, pid, "Scroll Rack: exile %s face down?" % card.data.card_name,
				swap_lands and card.data.is_land()):
			chosen.append(card)
	if chosen.is_empty():
		return
	for card in chosen:
		g.exile_from_hand(card, true, pid)
	for k in chosen.size():
		if g.top_of_library_to_hand(pid) == null: break
	var back: Array[CardInstance] = []
	for card in chosen:
		if card.zone == Mtg.Zone.EXILE: back.append(card)
	var ordered := _order_top(g, pid, back, "Scroll Rack: choose the next card from the top")
	# Exile to the top of the library, last first so the first answer ends
	# on top. Through the hand, unrevealed: the engine has no exile-to-
	# library move, and nothing in the pool hears a card reach a hand
	# outside a draw (tracked in the batch report).
	for n in range(ordered.size() - 1, -1, -1):
		g.return_from_exile_to_hand(ordered[n], false)
		g.put_from_hand_on_top_of_library(ordered[n])


# =============================================================== Wood Sage

## A creature card name from the activator's own decklist (the 2026-09-07
## ruling); a bare test game with no decklist names nothing, and every
## revealed card goes to the graveyard.
static func _wood_sage(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var names: Array[String] = []
	for name in NAMES.RiddleEffect.nameable(g, pid):
		var data := CardRegistry.get_card(name)
		if data != null and data.is_creature(): names.append(name)
	var named := ""
	if not names.is_empty():
		named = names[clampi(g.agents[pid].choose_option(g, pid, names, "Wood Sage: choose a creature card name", 0),
			0, names.size() - 1)]
	g.log_line("%s names %s (%s)" % [U.who(g, pid), named if named != "" else "nothing", s.data.card_name])
	var library := g.players[pid].library
	var revealed: Array[CardInstance] = []
	for k in mini(4, library.size()): revealed.append(library[library.size() - 1 - k])
	if revealed.is_empty():
		return
	g.reveal_information(-1, "Wood Sage reveals", U.names(revealed))
	g.log_line("%s reveals %s (Wood Sage)" % [U.who(g, pid), ", ".join(PackedStringArray(U.names(revealed)))])
	for card in revealed:
		if card.data.card_name == named: g.library_card_to_hand(card)
	for card in revealed:
		if card.zone == Mtg.Zone.LIBRARY: g.put_library_card_into_graveyard(card)
