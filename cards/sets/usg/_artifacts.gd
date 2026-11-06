extends RefCounted
## Urza's Saga (_artifacts, Pack 10). Noncreature artifacts and artifact
## creatures with abilities.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the shared vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd). The shared helpers below (the upkeep
## counters, "you", APNAP, the put-from-hand and reveal-search effects, the
## sacrifice of N permanents) are preloaded by the Legacy and Destiny
## modules (cards/sets/ulg/_artifacts.gd, cards/sets/uds/_artifacts.gd).
## tests/cards/test_pack_10_B8_*.gd pin each card.
##
## The upkeep counters (Barrin's Codex, Lotus Blossom, Smokestack; Powder
##   Keg in Destiny) — "you may put a <kind> counter": a yes/no to the
##   controller as the trigger resolves, only for the object that triggered
##   (CR 400.7). The hint is yes, except Smokestack's (below).
## Barrin's Codex — X is read from the activation's cost record
##   (MtgGame.activate_ability snapshots `_source_counters` before the
##   self-sacrifice), so it is what the artifact had as it was sacrificed
##   (CR 608.2h). Powder Keg reads its fuse counters the same way.
## Chimeric Staff — an AnimateSelfEffect sized by the ability's X; X = 0
##   makes a 0/0 the state-based check puts into the graveyard. The
##   animation joins layers 4 and 7b on the timestamp clock (CR 613.7).
## Citanul Flute — a search with a public reveal (MtgGame.search_library's
##   reveal title) whose filter reads the ability's X. Braidwood Sextant
##   (Destiny) is the same effect for a basic land card.
## Claws of Gix — "Sacrifice a permanent" may eat the Claws itself.
## Copper Gnomes — "you may put an artifact card from your hand onto the
##   battlefield" (Quicksilver Amulet's creature twin in Legacy): an
##   optional card choice, the arrival through
##   MtgGame.put_from_hand_into_play — not cast, so no casting trigger and
##   no land drop, but as-enters choices and arrival triggers apply.
## Endoskeleton — Tawnos's Weaponry's shape (4ed/tawnos_s_weaponry.gd):
##   the bonus holds while the artifact has stayed tapped since that
##   activation (CR 611.2b), so the 1997 tapped-artifact rule cannot switch
##   it off (StaticAbility.working_while_tapped).
## Grafted Skullcap — DRAW_STEP (after the normal draw, Howling Mine's
##   hook) and END_STEP_START, both its controller's.
## Lifeline — a DIES trigger with an intervening "if" asked again as it
##   resolves (CR 603.4): a sweep that kills every creature returns nothing.
##   The return is a delayed trigger (CR 603.7) for the dead CARD while it
##   is still the same graveyard object (CR 400.7); a token returns nothing.
## Lotus Blossom — Black Lotus's five abilities with a dynamic amount: the
##   petals are counted before the sacrifice is paid (MtgGame.tap_for_mana),
##   and a Blossom with none makes nothing (the mana planner skips it).
## Metrognome — Mangara's Blessing's shape (mir/_spells.gd): the card hears
##   its own CARD_DISCARDED, and only a discard an opponent's spell or
##   ability caused triggers it — a cost discard (cycling) or one the
##   owner caused never does. A real trigger on the stack (CR 603.3).
## Mishra's Helix — X target lands; role `tap_x_lands` (the AI taps the
##   opponent's untapped lands in that player's upkeep — alliances_tactics).
## Mobile Fort — Walking Wall's text (ice/_creatures.gd `_walk`).
## Noetic Scales — the bounced set is one simultaneous departure, sized by
##   the upkeep player's hand and each creature's live power on resolution.
## Phyrexian Processor — Minion of the Wastes's payment (tmp/_creatures.gd):
##   a replacement as it enters (CR 614.12; 119.4: 0 only at 0 life or
##   less), asked of a human seat through the resolution pre-flight. The
##   activation records the paid life with its cost, so the token is sized
##   even if the Processor has gone (CR 608.2h). The hint keeps a floor of
##   5 life plus twice the opponent's visible creature power.
## Purging Scythe — untargeted: the tied creatures are chosen on resolution
##   (CR 608.2d), by live toughness, both players'; shroud does not stop the
##   pick, protection still prevents the damage.
## Smokestack — two upkeep triggers; in its controller's upkeep the order
##   among them is that player's (the default resolves the sacrifice before
##   the new counter). Each sacrifice counts the soot as it resolves (last
##   known counters if the Smokestack has gone). The hint adds soot only
##   while its controller has more other permanents than the opponent: the
##   side with more outlasts a symmetric sacrifice.
## Umbilicus — the upkeep player is asked, never the controller; 2 life
##   can be paid only with 2 or more (CR 119.4).
## Urza's Armor — a static damage replacement (engine/damage_replacements.gd)
##   that prevents 1 of each damage event's damage to its controller. It is
##   a `replace` entry: a static `prevent` entry of the suite always
##   prevents the whole event (MtgGame.add_static_damage_effect resets its
##   points).
## Wirecat — reads live types: an enchantment that has stopped being one
##   (an Opal enchantment that became a creature) no longer counts.
const F := preload("res://cards/sets/fem/_rules.gd")
const MA := preload("res://cards/sets/mir/_artifacts.gd")
const ICE := preload("res://cards/sets/ice/_creatures.gd")
const PATH := "res://cards/sets/usg/_artifacts.gd"

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Barrin's Codex":
			c.triggered(upkeep_counter("page",
				"At the beginning of your upkeep, you may put a page counter on this artifact."))
			c.activated(ActivatedAbility.new("{4}", true, [Pages.new()],
				"{4}, {T}, Sacrifice this artifact: Draw X cards, where X is the number of page counters on this artifact.") \
				.with_sacrifice_cost())
		"Chimeric Staff":
			c.activated(ActivatedAbility.new("{X}", false, [Staff.new()],
				"{X}: This artifact becomes an X/X Construct artifact creature until end of turn."))
		"Citanul Flute":
			c.activated(ActivatedAbility.new("{X}", true,
				[RevealSearch.new("a creature card with mana value X or less", _creature_card_up_to_x, "Citanul Flute", true)],
				"{X}, {T}: Search your library for a creature card with mana value X or less, reveal it, put it into your hand, then shuffle."))
		"Claws of Gix":
			c.activated(ActivatedAbility.new("{1}", false, [GainLifeEffect.new(1)],
				"{1}, Sacrifice a permanent: You gain 1 life.") \
				.with_sacrifice_of("permanent", _permanent).may_sacrifice_itself())
		"Copper Gnomes":
			# No {T}: usable the turn it arrives (CR 302.6).
			c.activated(ActivatedAbility.new("{4}", false, [FromHand.new(Mtg.CardType.ARTIFACT, "an artifact")],
				"{4}, Sacrifice this creature: You may put an artifact card from your hand onto the battlefield.") \
				.with_sacrifice_cost())
		"Crystal Chimes":
			c.activated(ActivatedAbility.new("{3}", true,
				[F.Action.new(_chimes, "return all enchantment cards from your graveyard to your hand", null, true)],
				"{3}, {T}, Sacrifice this artifact: Return all enchantment cards from your graveyard to your hand.") \
				.with_sacrifice_cost())
		"Dragon Blood":
			c.activated(ActivatedAbility.new("{3}", true, [CounterMarkerEffect.new("+1/+1", 1, TargetSpec.creature())],
				"{3}, {T}: Put a +1/+1 counter on target creature."))
		"Endoskeleton":
			c.with_may_skip_untap()
			c.static_ability(StaticAbility.new(_brace,
				"The creature it targeted gets +0/+3 for as long as Endoskeleton remains tapped.").working_while_tapped())
			c.activated(ActivatedAbility.new("{2}", true, [Brace.new()],
				"{2}, {T}: Target creature gets +0/+3 for as long as this artifact remains tapped."))
		"Grafted Skullcap":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DRAW_STEP, _skullcap_draw,
				"At the beginning of your draw step, draw an additional card.", yours))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _skullcap_discard,
				"At the beginning of your end step, discard your hand.", yours))
		"Hopping Automaton":
			c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(-1, -1, [Mtg.Keyword.FLYING]).self_buff()],
				"{0}: This creature gets -1/-1 and gains flying until end of turn."))
		"Lifeline":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _lifeline,
				"Whenever a creature dies, if another creature is on the battlefield, return the first card to the battlefield under its owner's control at the beginning of the next end step.",
				_lifeline_due).capturing(_lifeline_context))
		"Lotus Blossom":
			c.triggered(upkeep_counter("petal",
				"At the beginning of your upkeep, you may put a petal counter on this artifact."))
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color, 1).with_sacrifice().with_dynamic_amount(_petals))
		"Metrognome":
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED, _metrognome_gnomes,
				"When a spell or ability an opponent controls causes you to discard this card, create four 1/1 colorless Gnome artifact creature tokens.",
				hostile_discard))
			c.activated(ActivatedAbility.new("{4}", true, [Gnomes.new(1)],
				"{4}, {T}: Create a 1/1 colorless Gnome artifact creature token."))
		"Mishra's Helix":
			c.activated(ActivatedAbility.new("{X}", true,
				[TapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)).x_targets() \
					.with_ai_role(&"tap_x_lands")],
				"{X}, {T}: Tap X target lands."))
		"Mobile Fort":
			c.activated(ActivatedAbility.new("{3}", false, [PumpEffect.new(3, -1).self_buff(),
				F.Action.new(ICE._walk, "this creature can attack this turn as though it didn't have defender")],
				"{3}: This creature gets +3/-1 until end of turn and can attack this turn as though it didn't have defender. Activate only once each turn.") \
				.per_turn(1))
		"Noetic Scales":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _scales,
				"At the beginning of each player's upkeep, return to its owner's hand each creature that player controls with power greater than the number of cards in their hand.",
				each_players))
		"Phyrexian Processor":
			c.as_it_enters(_processor_pay)
			var make := ActivatedAbility.new("{4}", true, [Minion.new()],
				"{4}, {T}: Create an X/X black Phyrexian Minion creature token, where X is the life paid as this artifact entered.")
			make.on_cost_paid = _processor_paid
			c.activated(make)
		"Purging Scythe":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _scythe,
				"At the beginning of your upkeep, this artifact deals 2 damage to the creature with the least toughness. If two or more creatures are tied for least toughness, you choose one of them.",
				yours))
		"Smokestack":
			c.triggered(upkeep_counter("soot",
				"At the beginning of your upkeep, you may put a soot counter on this artifact."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _smokestack,
				"At the beginning of each player's upkeep, that player sacrifices a permanent of their choice for each soot counter on this artifact.",
				each_players))
		"Umbilicus":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _umbilicus,
				"At the beginning of each player's upkeep, that player may pay 2 life. If they don't, they return a permanent they control to its owner's hand.",
				each_players))
		"Urza's Armor":
			c.static_ability(StaticAbility.new(_armor, "If a source would deal damage to you, prevent 1 of that damage."))
		"Whetstone":
			c.activated(ActivatedAbility.new("{3}", false, [F.Action.new(_whetstone, "each player mills two cards")],
				"{3}: Each player mills two cards."))
		"Wirecat":
			c.static_ability(StaticAbility.new(_wirecat,
				"This creature can't attack or block if an enchantment is on the battlefield."))
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func _permanent(_i: CardInstance) -> bool: return true
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _anything(_i: CardInstance) -> bool: return true

## "You" for a resolving trigger or ability: the player who controls it
## (CR 603.3a, 113.8) — the trigger's controller even after its source has
## left the battlefield.
static func you(g: MtgGame, s: CardInstance) -> int:
	return MA.pid_of(g, s)

## "Your <step>": the event's player controls this permanent.
static func yours(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == s.controller_id

## "Each player's <step>".
static func each_players(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) >= 0

## "Each opponent's <step>".
static func opponents(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var who := int(e.data.get("player", -1))
	return who >= 0 and who != s.controller_id

## "Each player", in APNAP order: the active player first (CR 101.4).
static func apnap(g: MtgGame) -> Array[int]:
	var order: Array[int] = [g.active_player, g.opponent_of(g.active_player)]
	return order

## "At the beginning of your upkeep, you may put a <kind> counter on this
## artifact."
static func upkeep_counter(kind: String, text: String) -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _may_counter.bind(kind), text, yours)

static func _may_counter(g: MtgGame, s: CardInstance, _e: GameEvent, kind: String) -> void:
	if not F._same_trigger_source(g, s): return
	var pid := you(g, s)
	var hint := soot_hint(g, s, pid) if kind == "soot" else true
	if g.agents[pid].choose_yes_no(g, pid, "Put a %s counter on %s?" % [kind, s.data.card_name], hint):
		g.add_counters(s, kind)

## Smokestack's soot: only while [param pid] controls more permanents
## besides the Smokestack than the opponent does (public counts).
static func soot_hint(g: MtgGame, s: CardInstance, pid: int) -> bool:
	var mine := g.players[pid].battlefield.size() - (1 if g.players[pid].battlefield.has(s) else 0)
	return mine > g.players[g.opponent_of(pid)].battlefield.size()

## What a permanent of a player's own is worth to them, for the order they
## give one up in: its mana value, a land between a one- and a two-drop.
static func worth(i: CardInstance) -> float:
	return 1.5 if i.is_land() else float(i.data.cost.mana_value())

## The order a player gives up their own permanents (their own board, which
## they see whole): tokens first, then the least worth.
static func cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	if a.is_token != b.is_token: return a.is_token
	if worth(a) != worth(b): return worth(a) < worth(b)
	return a.id < b.id

## "[param who] sacrifices [param count] permanents of their choice": one
## pick at a time, then one simultaneous sacrifice.
static func sacrifice_permanents(g: MtgGame, who: int, count: int, card_name: String) -> void:
	var choices: Array[CardInstance] = g.players[who].battlefield.duplicate()
	choices.sort_custom(cheapest_first)
	var total := mini(count, choices.size())
	var picked: Array[CardInstance] = []
	for n in total:
		var pick := g.agents[who].choose_card(g, who, choices,
			"%s: sacrifice a permanent (%d of %d)" % [card_name, n + 1, total])
		if pick == null or not choices.has(pick): pick = choices[0]
		picked.append(pick)
		choices.erase(pick)
	if picked.is_empty(): return
	g.begin_simultaneous()
	for i in picked: g.sacrifice_permanent(i)
	g.end_simultaneous()


# ----------------------------------------------- put a card from your hand --

## "You may put <a kind> card from your hand onto the battlefield" (Copper
## Gnomes, Quicksilver Amulet). The card in hand has no live types to read:
## its printed types decide.
class FromHand extends EffectBase:
	var kind: int
	var what: String
	func _init(type_flag: int, article_and_type: String) -> void:
		kind = type_flag
		what = article_and_type
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var choices: Array[CardInstance] = []
		for card in g.players[pid].hand:
			if card.data.is_type(kind): choices.append(card)
		if choices.is_empty(): return
		# The player's own hand, best first: the costliest card.
		choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := g.agents[pid].choose_card(g, pid, choices,
			"%s: you may put %s card from your hand onto the battlefield" % [s.data.card_name, what], true)
		if pick != null and choices.has(pick):
			g.put_from_hand_into_play(pick, pid)
	func describe() -> String:
		return "you may put %s card from your hand onto the battlefield" % what


# ---------------------------------------------------------- searched cards --

## "Search your library for <what>, reveal it, put it into your hand, then
## shuffle." With [member up_to_x] the filter also takes the ability's X.
class RevealSearch extends SearchLibraryEffect:
	var shown_by: String
	var up_to_x: bool
	func _init(what: String, fits: Callable, card_name: String, x_bound := false) -> void:
		super(what, fits)
		shown_by = card_name
		up_to_x = x_bound
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, x := 0) -> void:
		var fits := filter.bind(x) if up_to_x else filter
		var wanted := description.replace("X", str(x)) if up_to_x else description
		g.search_library(pid, fits, "%s: search your library for %s" % [shown_by, wanted], false, true,
			"%s reveals (%s)" % [g.players[pid].player_name, shown_by])

static func _creature_card_up_to_x(i: CardInstance, x: int) -> bool:
	return i.data.is_creature() and i.data.cost.mana_value() <= x


# ------------------------------------------------------------ Barrin's Codex --

class Pages extends DrawEffect:
	func _init() -> void:
		super(0)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var counters: Dictionary = g.cost_paid("_source_counters", {})
		var n := int(counters.get("page", 0))
		if n > 0: g.draw_cards(pid, n)
	func describe() -> String:
		return "draw X cards, where X is the number of page counters on this artifact"


# ------------------------------------------------------------ Chimeric Staff --

class Staff extends AnimateSelfEffect:
	func _init() -> void:
		super(Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE, 0, 0, ["construct"])
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, x := 0) -> void:
		if not MA.same_activation(g, s): return
		g.continuous.add_until_eot_animation(s.id, add_types, x, x, add_subtypes)
		g.log_line("%s becomes a %d/%d Construct artifact creature until end of turn" % [s.data.card_name, x, x])
		g.recalculate()
	func describe() -> String:
		return "becomes an X/X Construct artifact creature until end of turn"


# ------------------------------------------------------------ Crystal Chimes --

static func _chimes(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for card in g.players[pid].graveyard.duplicate():
		if card.data.is_type(Mtg.CardType.ENCHANTMENT):
			g.return_from_graveyard_to_hand(card)


# -------------------------------------------------------------- Endoskeleton --

class Brace extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var held := g.find_instance(t.instance_id)
		if not g.is_present(held): return
		# Untapped (or gone) since the activation: the duration has already
		# ended, so the effect does nothing (CR 611.2b).
		if not F._remained_tapped(g, s): return
		g._rec(s, &"memory")
		s.memory["holding"] = held.id
		s.memory["holding_stamp"] = held.layer_timestamp
		s.memory["holding_untaps"] = s.untap_sequence
		g.recalculate()
	func describe() -> String:
		return "target creature gets +0/+3 for as long as this artifact remains tapped"

## The bonus while Endoskeleton stays tapped. The first recalculation that
## finds it untapped (or the creature gone, a new object) ends the effect
## for good (CR 611.2b, 400.7).
static func _brace(g: MtgGame, s: CardInstance) -> void:
	if not s.memory.has("holding"): return
	var held := g.find_instance(int(s.memory["holding"]))
	if not s.tapped or s.untap_sequence != int(s.memory.get("holding_untaps", s.untap_sequence)) \
			or held == null or held.zone != Mtg.Zone.BATTLEFIELD \
			or held.layer_timestamp != int(s.memory.get("holding_stamp", -1)):
		g._rec(s, &"memory")
		s.memory.erase("holding")
		s.memory.erase("holding_stamp")
		s.memory.erase("holding_untaps")
		return
	if held.phased_out: return
	held.cur_toughness += 3


# ---------------------------------------------------------- Grafted Skullcap --

static func _skullcap_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(you(g, s), 1)

static func _skullcap_discard(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := you(g, s)
	if not g.players[pid].hand.is_empty():
		g.discard_hand(pid)


# ------------------------------------------------------------------ Lifeline --

## Is a creature on the battlefield other than [param besides]?
static func _creature_besides(g: MtgGame, besides: CardInstance) -> bool:
	for i in g.all_battlefield():
		if i != besides and i.is_creature(): return true
	return false

static func _lifeline_due(g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance")
	return dead != null and _creature_besides(g, dead)

static func _lifeline_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var dead: CardInstance = e.data.get("instance")
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"id": dead.id if dead != null else -1,
		"entry": int(e.data.get("graveyard_entry", -1)),
		"token": dead != null and dead.is_token}

static func _lifeline(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	# CR 603.4: the "if" is asked again; a sweep left nothing standing.
	if not _creature_besides(g, null): return
	var ctx := g.trigger_context(s)
	if bool(ctx.get("token", false)): return   # a token is not a card
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _lifeline_return,
		"Return the card that died to the battlefield under its owner's control."),
		you(g, s), s, false, {"id": int(ctx.get("id", -1)), "entry": int(ctx.get("entry", -1))})

static func _lifeline_return(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var card := g.find_instance(int(memory.get("id", -1)))
	if card != null and card.zone == Mtg.Zone.GRAVEYARD and card.graveyard_entry == int(memory.get("entry", -2)):
		g.reanimate(card, card.owner_id)


# -------------------------------------------------------------- Lotus Blossom --

static func _petals(_g: MtgGame, s: CardInstance) -> int:
	return int(s.counters.get("petal", 0))


# ----------------------------------------------------------------- Metrognome --

## "When a spell or ability an opponent controls causes you to discard this
## card": the card hears its own discard, by an effect an opponent controls.
static func hostile_discard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var cause := int(e.data.get("effect_controller", -1))
	return e.data.get("instance") == s and bool(e.data.get("by_effect", false)) \
		and cause != -1 and cause != s.owner_id

static func _metrognome_gnomes(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	# "You" is the player who discarded it: the card's owner.
	Gnomes.new(4).resolve(g, s, s.owner_id, null)

## The 1/1 colorless Gnome artifact creature token (CR 111.4).
class Gnomes extends CreateTokenEffect:
	func _init(number: int) -> void:
		super("Gnome", 1, 1, 0, "gnome", number)
		token.types |= Mtg.CardType.ARTIFACT
	func describe() -> String:
		if count == 1: return "create a 1/1 colorless Gnome artifact creature token"
		return "create %d 1/1 colorless Gnome artifact creature tokens" % count


# -------------------------------------------------------------- Noetic Scales --

static func _scales(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var limit := g.players[who].hand.size()
	var bounced: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature() and i.cur_power > limit: bounced.append(i)
	if bounced.is_empty(): return
	g.depart_together(bounced, func(i: CardInstance) -> void: g.return_to_hand(i))


# -------------------------------------------------------- Phyrexian Processor --

## The life the AI would pay: half its life at most, keeping a floor of 5
## plus twice the total power of the opponent's creatures (public board).
static func processor_hint(g: MtgGame, pid: int) -> int:
	var life: int = g.players[pid].life
	var threat := 0
	for i in g.players[g.opponent_of(pid)].battlefield:
		if i.is_creature(): threat += maxi(0, i.cur_power)
	return clampi(mini(life / 2, life - (5 + 2 * threat)), 0, maxi(life, 0))

static func _processor_pay(g: MtgGame, inst: CardInstance, pid: int) -> void:
	var life: int = g.players[pid].life
	var paid := 0
	if life > 0:
		paid = g.agents[pid].choose_number(g, pid, 0, life,
			"Phyrexian Processor: pay how much life?", processor_hint(g, pid))
	g._rec(inst, &"memory")
	inst.memory["paid"] = paid
	if paid > 0:
		g.adjust_life(pid, -paid)
	g.log_line("%s pays %d life for %s" % [g.players[pid].player_name, paid, inst.data.card_name])

static func _processor_paid(_g: MtgGame, s: CardInstance, paid: Dictionary) -> void:
	paid["_processor_life"] = int(s.memory.get("paid", 0))

## The X/X black Phyrexian Minion, X from the activation's cost record.
class Minion extends CreateTokenEffect:
	func _init() -> void:
		super("Phyrexian Minion", 0, 0, Mtg.ManaColor.B, "phyrexian")
		token.with_subtypes(["minion"])
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var n := int(g.cost_paid("_processor_life", 0))
		var body := CardData.new("Phyrexian Minion", "", Mtg.CardType.CREATURE).pt(n, n) \
			.with_colors(Mtg.ManaColor.B).with_subtypes(["phyrexian", "minion"])
		g.create_token(pid, body)
	func describe() -> String:
		return "create an X/X black Phyrexian Minion creature token, where X is the life paid as this artifact entered"


# -------------------------------------------------------------- Purging Scythe --

static func _scythe(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := you(g, s)
	var least := 0
	var tied: Array[CardInstance] = []
	for i in g.all_battlefield():
		if not i.is_creature(): continue
		if tied.is_empty() or i.cur_toughness < least:
			least = i.cur_toughness
			tied.clear()
			tied.append(i)
		elif i.cur_toughness == least:
			tied.append(i)
	if tied.is_empty(): return
	var pick: CardInstance = tied[0]
	if tied.size() > 1:
		# The chooser's order: the opponents' creatures first, then the
		# public value (a face-down body is worth its masked 2/2 only).
		tied.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if (a.controller_id == pid) != (b.controller_id == pid): return b.controller_id == pid
			var va := a.cur_power + g.copiable_data(a).cost.mana_value()
			var vb := b.cur_power + g.copiable_data(b).cost.mana_value()
			if va != vb: return va > vb
			return a.id < b.id)
		var chosen := g.agents[pid].choose_card(g, pid, tied,
			"Purging Scythe: choose the creature to deal 2 damage to", false, false, true)
		if chosen != null and tied.has(chosen): pick = chosen
	g.deal_damage(s, TargetRef.card(pick), 2)


# ----------------------------------------------------------------- Smokestack --

static func _smokestack(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var counters: Dictionary = s.counters if F._same_trigger_object(g, s) else s.last_counters
	var n := int(counters.get("soot", 0))
	if n > 0: sacrifice_permanents(g, who, n, "Smokestack")


# ------------------------------------------------------------------ Umbilicus --

## The bounce order for the returning player: a card before a token (a
## token would cease to exist), then the least worth.
static func _bounce_first(a: CardInstance, b: CardInstance) -> bool:
	if a.is_token != b.is_token: return b.is_token
	if worth(a) != worth(b): return worth(a) < worth(b)
	return a.id < b.id

static func _umbilicus(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var life: int = g.players[who].life
	if life >= 2 and g.agents[who].choose_yes_no(g, who,
			"Umbilicus: pay 2 life? If you don't, return a permanent you control to its owner's hand.", life >= 8):
		g.adjust_life(who, -2)
		return
	var choices: Array[CardInstance] = g.players[who].battlefield.duplicate()
	if choices.is_empty(): return
	choices.sort_custom(_bounce_first)
	var pick := g.agents[who].choose_card(g, who, choices,
		"Umbilicus: return a permanent you control to its owner's hand")
	if pick == null or not choices.has(pick): pick = choices[0]
	g.return_to_hand(pick)


# ---------------------------------------------------------------- Urza's Armor --

static func _armor(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"replace", "desc": "Urza's Armor",
		"victims": [{"player": s.controller_id}], "apply": _armor_prevents})

## Prevent 1 of this damage event's damage (CR 615): -1 carries the rest
## on through the other gates, 0 ends an event with nothing left.
static func _armor_prevents(g: MtgGame, packet: DamagePacket) -> int:
	var stopped := packet.prevent(1)
	if stopped > 0:
		g.log_line("Urza's Armor prevents 1 damage from %s" % packet.source.data.card_name)
	return 0 if packet.remaining() <= 0 else -1


# ------------------------------------------------------------------ Whetstone --

static func _whetstone(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for who in apnap(g):
		g.mill(who, 2)


# -------------------------------------------------------------------- Wirecat --

static func _wirecat(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_type(Mtg.CardType.ENCHANTMENT):
			s.cur_cant_attack = true
			s.cur_cant_block_filter = _anything
			return
