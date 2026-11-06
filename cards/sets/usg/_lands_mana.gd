extends RefCounted
## Urza's Saga (_lands_mana, Pack 10). Lands and mana abilities.
##
## Every mana source is declared in a shape the one mana planner
## (engine/mana_planner.gd — the AI's plans and the human auto-pay) reads
## without running a callback, as Pack 9's lands are: fixed outputs, "any
## color" as one ability per colour (Birds of Paradise), self-sacrifice as
## ManaAbility.with_sacrifice and "Sacrifice a creature" as
## with_sacrifice_of (never auto-planned), an object cost (Skirge Familiar's
## discard) never auto-planned either.
##
## - The counting sources — Gaea's Cradle (creatures you control), Serra's
##   Sanctum (enchantments), Tolarian Academy (artifacts), Priest of
##   Titania (every Elf on the battlefield) — are dynamic amounts over LIVE
##   types and subtypes (CONTRIBUTING rule 5): an animated land is a
##   creature, an artifact creature an artifact. "You" is the activating
##   player (CR 109.5, ManaAbility.amount_reads_activator). A source that
##   counts nothing makes nothing, and the planner never counts it (CR
##   106.7). The four Saga lands that print Legendary are legends: a second
##   of one name is buried by the 1997 legend rule.
## - Citanul Hierophants: the first card to grant a MANA ability to other
##   permanents. A layer-6 static (changing_abilities, CR 613.1f) appends
##   one shared ManaAbility — built once per card, since the live lists are
##   compared by identity — to each creature its controller controls, so
##   tap_for_mana and the planner both read it from the creature's live
##   list and both keep summoning sickness (CR 302.6; haste lifts it). Two
##   Hierophants grant it twice; Humility takes it away.
## - Witch Engine: "{T}: Add {B}{B}{B}{B}. Target opponent gains control
##   of this creature." targets, so it is NOT a mana ability (CR 605.1a):
##   an activated ability on the stack whose resolution adds the mana to
##   the activator's pool and then gives the creature away (if it is still
##   the object activated, CR 400.7).
## - Carpet of Flowers: at the beginning of each of its controller's main
##   phases (MAIN_PHASE_START, precombat or not) it targets an opponent;
##   the intervening "if you haven't added mana with this ability this
##   turn" is checked as it triggers and again on resolution (CR 603.4),
##   remembered on the object by turn number. The mana is a "you may" and
##   one colour of the controller's choice — a declined trigger in the
##   first main phase comes back in the second.
## - Vernal Bloom: Gauntlet of Might's mana trigger on a Forest, for that
##   Forest's controller (described to the planner).
## - Thran Quarry: "at the beginning of THE end step" — every end step,
##   either player's — with its intervening if.
## - Shivan Gorge: the damage is the land's, to each opponent of its
##   activator.
##
## tests/cards/test_pack_10_B9_lands_mana.gd and
## test_pack_10_B9_hierophants.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const OC := preload("res://engine/additional_object_costs.gd")

const CARPET_TEXT := "At the beginning of each of your main phases, if you haven't added mana with this ability this turn, you may add X mana of any one color, where X is the number of Islands target opponent controls."

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Blood Vassal":
			# No {T}: usable the turn it arrives (CR 302.6).
			c.mana(ManaAbility.new(Mtg.ManaColor.B, 2).without_tap().with_sacrifice())
		"Skirge Familiar":
			c.mana(ManaAbility.new(Mtg.ManaColor.B).without_tap().with_object_cost(OC.discarding()))
		"Witch Engine":
			c.activated(ActivatedAbility.new("", true, [AddManaEffect.new(Mtg.ManaColor.B, 4), Gift.new()],
				"{T}: Add {B}{B}{B}{B}. Target opponent gains control of this creature. (Activate only as an instant.)"))
		"Carpet of Flowers":
			c.triggered(TriggeredAbility.new(Mtg.EventType.MAIN_PHASE_START, _carpet, CARPET_TEXT,
				_carpet_due).targeting(TargetSpec.opponent(), Callable(), "Carpet of Flowers: select target opponent."))
		"Citanul Hierophants":
			var grant := ManaAbility.new(Mtg.ManaColor.G)
			c.static_ability(StaticAbility.new(_hierophants.bind(grant),
				"Creatures you control have \"{T}: Add {G}.\"").changing_abilities())
		"Priest of Titania":
			c.mana(ManaAbility.new(Mtg.ManaColor.G).with_dynamic_amount(_elves))
		"Vernal Bloom":
			var bloom := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _bloom,
				"Whenever a Forest is tapped for mana, its controller adds an additional {G}.",
				_is_forest).as_mana_trigger()
			bloom.mana_bonus_subtype = "forest"
			bloom.mana_bonus_color = Mtg.ManaColor.G
			bloom.mana_bonus_amount = 1
			c.triggered(bloom)
		"Worn Powerstone":
			c.with_enters_tapped()
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 2))
		"Gaea's Cradle":
			c.mana(ManaAbility.new(Mtg.ManaColor.G).with_dynamic_amount(_yours_of.bind(Mtg.CardType.CREATURE), true))
		"Phyrexian Tower":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.mana(ManaAbility.new(Mtg.ManaColor.B, 2).with_sacrifice_of("creature", F._creature))
		"Serra's Sanctum":
			c.mana(ManaAbility.new(Mtg.ManaColor.W).with_dynamic_amount(_yours_of.bind(Mtg.CardType.ENCHANTMENT), true))
		"Shivan Gorge":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{2}{R}", true,
				[F.Action.new(_gorge, "deals 1 damage to each opponent")],
				"{2}{R}, {T}: Shivan Gorge deals 1 damage to each opponent."))
		"Thran Quarry":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _quarry,
				"At the beginning of the end step, if you control no creatures, sacrifice this land.",
				_quarry_due))
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color))
		"Tolarian Academy":
			c.mana(ManaAbility.new(Mtg.ManaColor.U).with_dynamic_amount(_yours_of.bind(Mtg.CardType.ARTIFACT), true))
		_: return false
	return true


# ------------------------------------------------------- counting sources --

## How many permanents of [param type] (live types) [param pid] controls.
static func _yours_of(g: MtgGame, _s: CardInstance, pid: int, type: int) -> int:
	if pid < 0 or pid >= g.players.size(): return 0
	var n := 0
	for inst in g.players[pid].battlefield:
		if not inst.phased_out and inst.is_type(type): n += 1
	return n

## "For each Elf on the battlefield" — both players', live subtypes.
static func _elves(g: MtgGame, _s: CardInstance) -> int:
	var n := 0
	for inst in g.all_battlefield():
		if not inst.phased_out and inst.has_subtype("elf"): n += 1
	return n


# --------------------------------------------------- Citanul Hierophants --

static func _hierophants(g: MtgGame, s: CardInstance, grant: ManaAbility) -> void:
	for inst in g.players[s.controller_id].battlefield:
		if not inst.phased_out and inst.is_creature():
			inst.cur_mana_abilities.append(grant)


# ---------------------------------------------------------- Vernal Bloom --

static func _is_forest(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	var inst: CardInstance = e.data.get("instance")
	return inst != null and inst.is_land() and inst.has_subtype("forest")

## "Its controller" is the Forest's (the event's `controller`).
static func _bloom(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	g.players[int(e.data["controller"])].mana_pool.add(Mtg.ManaColor.G, 1)


# ---------------------------------------------------------- Witch Engine --

class Gift extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if F._same_activation_source(g, s) and t != null and t.is_player:
			g.change_control(s, t.player_id)

	func describe() -> String:
		return "target opponent gains control of this creature"


# ------------------------------------------------------ Carpet of Flowers --

## Your main phase, and no mana from this ability yet this turn.
static func _carpet_due(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("player", -1)) == s.controller_id \
		and int(s.memory.get("carpet_turn", -1)) != g.turn_number

static func _carpet(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := M.pid_of(g, s)
	if F._same_trigger_object(g, s) and int(s.memory.get("carpet_turn", -1)) == g.turn_number:
		return   # CR 603.4: the "if" is false now
	var targets := g.current_targets()
	if targets.is_empty() or not targets[0].is_player:
		return
	var islands := 0
	for land in g.players[targets[0].player_id].battlefield:
		if not land.phased_out and land.is_land() and land.has_subtype("island"): islands += 1
	if islands <= 0:
		return
	var hint := not g.rules.mana_burn or _has_a_spell(g, pid)
	if not g.agents[pid].choose_yes_no(g, pid,
			"Carpet of Flowers: add %d mana of any one color?" % islands, hint):
		return
	var color := g.agents[pid].choose_color(g, pid,
		"Carpet of Flowers: choose a color", _wanted_color(g, pid))
	if not Mtg.WUBRG.has(color): color = Mtg.ManaColor.G
	AddManaEffect.new(color, islands).resolve(g, s, pid, null)
	if F._same_trigger_object(g, s):
		g._rec(s, &"memory")
		s.memory["carpet_turn"] = g.turn_number

## A nonland card in [param pid]'s own hand (their own knowledge).
static func _has_a_spell(g: MtgGame, pid: int) -> bool:
	for card in g.players[pid].hand:
		if not card.data.is_type(Mtg.CardType.LAND): return true
	return false

## The colour [param pid]'s own hand asks for most (green when none).
static func _wanted_color(g: MtgGame, pid: int) -> int:
	var best := Mtg.ManaColor.G
	var most := 0
	for color in Mtg.WUBRG:
		var n := 0
		for card in g.players[pid].hand:
			n += int(card.data.cost.colored.get(color, 0))
		if n > most:
			most = n
			best = color
	return best


# --------------------------------------------------------- Shivan Gorge --

static func _gorge(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.deal_damage(s, TargetRef.player(g.opponent_of(pid)), 1)


# --------------------------------------------------------- Thran Quarry --

static func _no_creature(g: MtgGame, pid: int) -> bool:
	for inst in g.players[pid].battlefield:
		if not inst.phased_out and inst.is_creature(): return false
	return true

static func _quarry_due(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return _no_creature(g, s.controller_id)

static func _quarry(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._trigger_source_present(g, s) or not _no_creature(g, s.controller_id):
		return   # gone, or a creature arrived (CR 603.4)
	g.sacrifice_permanent(s)
