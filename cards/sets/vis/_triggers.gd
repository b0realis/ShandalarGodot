extends RefCounted
## Visions (_triggers, Pack 8). Triggered abilities: enters, dies, upkeep, end step and other event triggers.
##
## Same conventions as the Mirage module (cards/sets/mir/_triggers.gd, whose
## shared helpers this reuses as M): triggers resolve with last known
## information for the seat that controlled them (CR 603.6 / 608.2h),
## intervening "if"s are rechecked (CR 603.4), and only the clauses that name
## the source check that the very same object is still there.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Dream Tides":
			c.static_ability(StaticAbility.new(_tides_lock,
				"Creatures don't untap during their controllers' untap steps."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _tides_pay,
				"At the beginning of each player's upkeep, that player may choose any number of tapped nongreen creatures they control and pay {2} for each creature chosen this way. If the player does, untap those creatures."))
		"Shrieking Drake":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _drake,
				"When this creature enters, return a creature you control to its owner's hand.", F._self_enter))
		"Waterspout Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _waterspout,
				"At the beginning of your upkeep, sacrifice this creature unless you return an untapped Island you control to its owner's hand.",
				F._your_upkeep))
		"Aku Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _aku,
				"At the beginning of your upkeep, put a +1/+1 counter on each creature each opponent controls.", F._your_upkeep))
		"Brood of Cockroaches":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _brood,
				"When this creature is put into your graveyard from the battlefield, at the beginning of the next end step, you lose 1 life and return this card to your hand.",
				_brood_to_your_graveyard).capturing(M._dead_context))
		"Nekrataal":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _destroy_target.bind(false),
				"When this creature enters, destroy target nonartifact, nonblack creature. That creature can't be regenerated.",
				F._self_enter).targeting(TargetSpec.creature("target nonartifact, nonblack creature", _nonartifact_nonblack),
				F._enemy_first, "Destroy target nonartifact, nonblack creature."))
		"Bogardan Phoenix":
			var phoenix := TriggeredAbility.new(Mtg.EventType.DIES, _phoenix,
				"When this creature dies, exile it if it had a death counter on it. Otherwise, return it to the battlefield under your control and put a death counter on it.",
				F._self_enter).capturing(_phoenix_context)
			phoenix.returns_source_after_death = true
			c.triggered(phoenix)
		"Goblin Recruiter":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _recruiter,
				"When this creature enters, search your library for any number of Goblin cards, reveal them, then shuffle and put those cards on top in any order.",
				F._self_enter))
		"Kookus":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _kookus,
				"At the beginning of your upkeep, if you don't control a creature named Keeper of Kookus, this creature deals 3 damage to you and attacks this turn if able.",
				_kookus_unkept))
			c.activated(F._ability("{R}", false, PumpEffect.new(1, 0).self_buff()))
		"Lightning Cloud":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _cloud,
				"Whenever a player casts a red spell, you may pay {R}. If you do, this enchantment deals 1 damage to any target.",
				M.spell_of.bind(Mtg.ManaColor.R)).targeting(TargetSpec.any_target(), _ping_order,
				"Lightning Cloud: choose any target for 1 damage."))
		"Viashino Sandstalker":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _sandstalker,
				"At the beginning of the end step, return this creature to its owner's hand."))
		"Bull Elephant":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _bull,
				"When this creature enters, sacrifice it unless you return two Forests you control to their owner's hand.",
				F._self_enter))
		"Rowen":
			# "Reveal the first card you draw each turn" is a STATIC ability,
			# not a trigger: the card is shown as it is drawn, with no stack
			# object in between. It rides the dispatcher's only off-stack
			# event path (TriggeredAbility.as_mana_trigger, which resolves on
			# the spot); the draw that follows a basic land IS a trigger.
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DRAWN, _rowen_reveal,
				"Reveal the first card you draw each turn.", _first_draw).as_mana_trigger())
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DRAWN, _rowen_draw,
				"Whenever you reveal a basic land card this way, draw a card.", _first_draw_basic_land))
		"Stampeding Wildebeests":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wildebeests,
				"At the beginning of your upkeep, return a green creature you control to its owner's hand.", F._your_upkeep))
		"Uktabi Orangutan":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _destroy_target.bind(true),
				"When this creature enters, destroy target artifact.", F._self_enter).targeting(
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact), F._enemy_first,
				"Destroy target artifact."))
		"Femeref Enchantress":
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _draw_one,
				"Whenever an enchantment is put into a graveyard from the battlefield, draw a card.", _enchantment_to_graveyard))
		"Suleiman's Legacy":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _legacy_sweep,
				"When this enchantment enters, destroy all Djinns and Efreets. They can't be regenerated.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _legacy_destroy,
				"Whenever a Djinn or Efreet enters, destroy it. It can't be regenerated.", _djinn_enters).capturing(_entrant_context))
		"Tar Pit Warrior":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, M.sacrifice_source,
				"When this creature becomes the target of a spell or ability, sacrifice it.", M.targeted_me))
		"Desolation":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _desolation,
				"At the beginning of each end step, each player who tapped a land for mana this turn sacrifices a land of their choice. This enchantment deals 2 damage to each player who sacrificed a Plains this way."))
		_: return false
	return true


static func _nonartifact_nonblack(i: CardInstance) -> bool:
	return not i.is_type(Mtg.CardType.ARTIFACT) and not i.has_color(Mtg.ManaColor.B)

static func _artifact(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT)

static func _djinn_or_efreet(i: CardInstance) -> bool:
	return i.has_subtype("djinn") or i.has_subtype("efreet")

static func _draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)

## Nekrataal (no regeneration) and Uktabi Orangutan: the trigger's one
## target, already rechecked for legality by the engine (CR 608.2b).
static func _destroy_target(g: MtgGame, _s: CardInstance, _e: GameEvent, can_regenerate: bool) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if victim != null: g.destroy(victim, can_regenerate)


# --------------------------------------------------------------- Dream Tides --

static func _tides_lock(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_skips_untap = true

## The UPKEEP player chooses (not Dream Tides' controller), any number of
## their tapped nongreen creatures at {2} each, then pays for them all at
## once; a payment that fails untaps none (CR 601.2h-style all-or-nothing).
static func _tides_pay(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", -1))
	if who < 0: return
	var pool := M.creatures_of(g, who, func(i: CardInstance) -> bool:
		return i.tapped and not i.has_color(Mtg.ManaColor.G))
	pool.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power + a.cur_toughness > b.cur_power + b.cur_toughness)
	var chosen: Array[CardInstance] = []
	while not pool.is_empty() and g.can_afford_cost(who, ManaCost.parse("{%d}" % (2 * (chosen.size() + 1)))):
		var one := g.agents[who].choose_card(g, who, pool,
			"Dream Tides: choose a tapped nongreen creature to untap for {2} (%d chosen)" % chosen.size(), true)
		if one == null or not pool.has(one): break
		chosen.append(one)
		pool.erase(one)
	if chosen.is_empty() or not g.try_pay(who, ManaCost.parse("{%d}" % (2 * chosen.size()))):
		return
	for i in chosen:
		if i.zone == Mtg.Zone.BATTLEFIELD: g.untap_permanent(i)


# ----------------------------------------------------------- Shrieking Drake --

## Not targeted: the creature is chosen on resolution, and the Drake itself
## is a legal (and the heuristic's first) choice.
static func _drake(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var mine := M.creatures_of(g, pid)
	if mine.is_empty(): return
	mine.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if (a == s) != (b == s): return a == s
		return a.data.cost.mana_value() < b.data.cost.mana_value())
	g.return_to_hand(M.pick(g, pid, mine, "Return a creature you control to its owner's hand"))


# ---------------------------------------------------------- Waterspout Djinn --

static func _waterspout(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not F._trigger_source_present(g, s) or s.controller_id != pid: return
	var islands: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land() and i.has_subtype("island") and not i.tapped: islands.append(i)
	if not islands.is_empty() and g.agents[pid].choose_yes_no(g, pid,
			"Return an untapped Island you control to its owner's hand to keep Waterspout Djinn?", true):
		g.return_to_hand(M.pick(g, pid, islands, "Return an untapped Island you control"))
		return
	g.sacrifice_permanent(s)


# ------------------------------------------------------------------ Aku Djinn --

static func _aku(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var foes := M.creatures_of(g, g.opponent_of(M.pid_of(g, s)))
	g.begin_simultaneous()
	for i in foes: g.add_counters(i, "+1/+1")
	g.end_simultaneous()


# ------------------------------------------------------- Brood of Cockroaches --

## "Put into YOUR graveyard": a card goes to its owner's graveyard, so a
## borrowed Brood dying under its thief's control does not trigger.
static func _brood_to_your_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and not s.is_token \
		and s.owner_id == int(e.data.get("controller", s.owner_id))

static func _brood(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var entry := int(g.trigger_context(s).get("entry", -1))
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START,
		_brood_return.bind(entry, pid), "Lose 1 life and return Brood of Cockroaches to your hand."), pid, s)

## The life loss happens even when the card is gone (CR 609.3: do as much as
## possible); the return needs the same graveyard object (CR 400.7).
static func _brood_return(g: MtgGame, s: CardInstance, _e: GameEvent, entry: int, pid: int) -> void:
	g.adjust_life(pid, -1)
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == entry:
		g.return_from_graveyard_to_hand(s)


# ----------------------------------------------------------- Bogardan Phoenix --

## Whether it HAD a death counter is last known information (CR 608.2h),
## captured as it died.
static func _phoenix_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := M._dead_context(g, s, e)
	ctx["had_death"] = int(s.last_counters.get("death", 0)) > 0
	return ctx

static func _phoenix(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	if s.zone != Mtg.Zone.GRAVEYARD or s.graveyard_entry != int(ctx.get("entry", -1)):
		return
	if bool(ctx.get("had_death", false)):
		g.exile_from_graveyard(s)
		return
	g.reanimate(s, M.pid_of(g, s))
	if s.zone == Mtg.Zone.BATTLEFIELD:
		g.add_counters(s, "death")


# ----------------------------------------------------------- Goblin Recruiter --

## Any number of Goblin cards, revealed; the library is shuffled and the
## chosen cards go on top in the order their owner names (first named ends
## on top). The search sees the library (CR 701.19b); the candidates are
## sorted by name so the list never leaks the library's order.
static func _recruiter(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var found: Array[CardInstance] = []
	while true:
		var candidates: Array[CardInstance] = []
		for card in g.players[pid].library:
			if card.data.subtypes.has("goblin") and not found.has(card): candidates.append(card)
		if candidates.is_empty(): break
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.card_name < b.data.card_name)
		var one := g.agents[pid].choose_card(g, pid, candidates,
			"Goblin Recruiter: choose a Goblin card (%d chosen)" % found.size(), true)
		if one == null or not candidates.has(one): break
		found.append(one)
	if not found.is_empty():
		var names: Array = []
		for card in found: names.append(card.data.card_name)
		g.reveal_information(-1, "Goblin Recruiter reveals", names)
		g.log_line("Goblin Recruiter reveals %s" % ", ".join(PackedStringArray(names)))
	g.shuffle_library(pid)
	var order: Array[CardInstance] = []
	var rest := found.duplicate()
	while rest.size() > 1:
		# Not ranked (alphabetical): the seat's own judgement orders them.
		var next := M.pick(g, pid, rest, "Goblin Recruiter: choose the next card from the top", false)
		order.append(next)
		rest.erase(next)
	order.append_array(rest)
	for n in range(order.size() - 1, -1, -1):
		g.move_library_card_to_top(order[n])


# --------------------------------------------------------------------- Kookus --

static func _controls_keeper(g: MtgGame, pid: int) -> bool:
	for i in g.players[pid].battlefield:
		if i.is_creature() and i.data.card_name == "Keeper of Kookus": return true
	return false

## Intervening "if" (CR 603.4): no Keeper as the upkeep begins AND on resolution.
static func _kookus_unkept(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and not _controls_keeper(g, s.controller_id)

static func _kookus(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if _controls_keeper(g, pid): return
	g.deal_damage(s, TargetRef.player(pid), 3)
	if F._same_trigger_source(g, s):
		g._rec(s, &"must_attack_this_turn")
		s.must_attack_this_turn = true


# ------------------------------------------------------------ Lightning Cloud --

## The target is named as the trigger goes on the stack (CR 603.3d); the
## {R} is offered on resolution. Preference: an enemy creature the 1 damage
## kills, then the opposing player, then any other enemy creature.
static func _ping_order(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return _ping_score(g, s, a) > _ping_score(g, s, b)

static func _ping_score(g: MtgGame, s: CardInstance, t: TargetRef) -> int:
	var me := g.controller_acting_for(s)
	if t.is_player:
		return 2000 if t.player_id != me else -2000
	var i := g.find_instance(t.instance_id)
	if i == null: return -3000
	if i.controller_id == me: return -1000 - i.cur_power
	if i.cur_toughness - i.damage <= 1: return 3000 + i.cur_power
	return 1000 + i.cur_power

static func _cloud(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var t: TargetRef = targets[0]
	var pid := M.pid_of(g, s)
	var hostile := (t.is_player and t.player_id != pid) \
		or (not t.is_player and g.find_instance(t.instance_id) != null and g.find_instance(t.instance_id).controller_id != pid)
	if EffectBase.unless_paid(g, pid, ManaCost.parse("{R}"), "Pay {R} for Lightning Cloud to deal 1 damage?", hostile):
		g.deal_damage(s, t, 1)


# ------------------------------------------------------- Viashino Sandstalker --

static func _sandstalker(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.return_to_hand(s)


# -------------------------------------------------------------- Bull Elephant --

static func _bull(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if not F._trigger_source_present(g, s) or s.controller_id != pid: return
	var forests: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land() and i.has_subtype("forest"): forests.append(i)
	forests.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return a.tapped and not b.tapped)
	if forests.size() >= 2 and g.agents[pid].choose_yes_no(g, pid,
			"Return two Forests you control to their owner's hand to keep Bull Elephant?", true):
		var first := M.pick(g, pid, forests, "Return a Forest you control (1 of 2)")
		forests.erase(first)
		var second := M.pick(g, pid, forests, "Return a Forest you control (2 of 2)")
		g.return_to_hand(first)
		g.return_to_hand(second)
		return
	g.sacrifice_permanent(s)


# ---------------------------------------------------------------------- Rowen --

static func _first_draw(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var pid := int(e.data.get("player", -1))
	if pid != s.controller_id: return false
	var drawn: Array = g.players[pid].drawn_this_turn
	return not drawn.is_empty() and drawn[0] == e.data.get("instance")

static func _first_draw_basic_land(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var card: CardInstance = e.data.get("instance")
	return card != null and _first_draw(g, s, e) and card.data.is_land() \
		and (card.data.supertypes & Mtg.Supertype.BASIC) != 0

static func _rowen_reveal(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var card: CardInstance = e.data.get("instance")
	if card == null: return
	g.reveal_information(-1, "Rowen: the first card drawn this turn", [card.data.card_name])
	g.log_line("Rowen: %s reveals %s" % [g.players[s.controller_id].player_name, card.data.card_name])

static func _rowen_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)


# ----------------------------------------------------- Stampeding Wildebeests --

static func _wildebeests(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	var green := M.creatures_of(g, pid, func(i: CardInstance) -> bool: return i.has_color(Mtg.ManaColor.G))
	if green.is_empty(): return
	M.least_valuable_first(green, s)
	g.return_to_hand(M.pick(g, pid, green, "Return a green creature you control to its owner's hand"))


# -------------------------------------------------------- Femeref Enchantress --

## LEAVES_BATTLEFIELD fires for every exit; "put into a graveyard" is the
## card's zone as the event is dispatched (a token is there too, briefly —
## CR 111.7), and "an enchantment" is last known information (CR 608.2h).
static func _enchantment_to_graveyard(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var gone: CardInstance = e.data.get("instance")
	return gone != null and gone.zone == Mtg.Zone.GRAVEYARD \
		and (gone.last_types & Mtg.CardType.ENCHANTMENT) != 0


# --------------------------------------------------------- Suleiman's Legacy --

static func _legacy_sweep(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var doomed: Array[CardInstance] = []
	for i in g.all_battlefield():
		if _djinn_or_efreet(i): doomed.append(i)
	g.begin_simultaneous()
	for i in doomed: g.destroy(i, false)
	g.end_simultaneous()

static func _djinn_enters(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var entrant: CardInstance = e.data.get("instance")
	return entrant != null and entrant != s and _djinn_or_efreet(entrant)

static func _entrant_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var ctx := F._source_context(g, s, e)
	var entrant: CardInstance = e.data.get("instance")
	ctx["id"] = entrant.id
	ctx["stamp"] = entrant.layer_timestamp
	return ctx

## "Destroy it" — the creature that entered, while it is still that object.
static func _legacy_destroy(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var entrant := g.find_instance(int(ctx.get("id", -1)))
	if entrant != null and entrant.zone == Mtg.Zone.BATTLEFIELD and entrant.layer_timestamp == int(ctx.get("stamp", -1)):
		g.destroy(entrant, false)


# ----------------------------------------------------------------- Desolation --

## Read as the ability resolves (E10's tracker: the player who ACTIVATED a
## land's mana ability this turn). Each such player chooses in APNAP order
## (CR 101.4), the lands go together, and the Plains test is the land as it
## was sacrificed. The 2 damage comes from Desolation, as it last existed if
## it has left (CR 608.2h), to every such player at once.
static func _desolation(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var picked: Array[CardInstance] = []
	for pid in [g.active_player, g.opponent_of(g.active_player)]:
		if not g.players[pid].tapped_land_for_mana_this_turn: continue
		var lands: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if i.is_land(): lands.append(i)
		if lands.is_empty(): continue
		lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			if a.has_subtype("plains") != b.has_subtype("plains"): return b.has_subtype("plains")
			return a.tapped and not b.tapped)
		picked.append(M.pick(g, pid, lands, "Desolation: sacrifice a land"))
	var burned: Array[int] = []
	for land in picked:
		if land.has_subtype("plains"): burned.append(land.controller_id)
	g.begin_simultaneous()
	for land in picked: g.sacrifice_permanent(land)
	g.end_simultaneous()
	if burned.is_empty(): return
	g.begin_simultaneous()
	for pid in burned: g.deal_damage(s, TargetRef.player(pid), 2)
	g.end_simultaneous()
