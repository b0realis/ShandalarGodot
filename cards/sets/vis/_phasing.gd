extends RefCounted
## Visions (_phasing, Pack 8). Phasing and the cards that phase permanents in and out.
##
## Same conventions as the Mirage module (cards/sets/mir/_phasing.gd, whose
## helper class H and effect classes this one shares): engine package E1
## does the phasing itself (MtgGame.phase_out / phase_simultaneously, the
## untap-step action, PHASED_IN), and every choice is the right seat's own
## question with a hint read off the public battlefield.
const F := preload("res://cards/sets/fem/_rules.gd")
const PH := preload("res://cards/sets/mir/_phasing.gd")

const REALM_LABELS: Array[String] = ["Artifact", "Creature", "Land", "Non-Aura enchantment"]


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Breezekeeper":
			PH.H.phasing(c)
		"Rainbow Efreet":
			c.activated(ActivatedAbility.new("{U}{U}", false, [PH.PhaseOutSelf.new()],
				"{U}{U}: This creature phases out."))
		"Teferi's Honor Guard":
			if not c.keywords.has(Mtg.Keyword.FLANKING): c.with_keywords([Mtg.Keyword.FLANKING])
			c.activated(ActivatedAbility.new("{U}{U}", false, [PH.PhaseOutSelf.new()],
				"{U}{U}: This creature phases out."))
		"Shimmering Efreet":
			PH.H.phasing(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.PHASED_IN, _efreet_shimmer,
				"Whenever this creature phases in, target creature phases out.", PH.H.is_self)
				.targeting(TargetSpec.creature(), _enemy_first, "Select a creature to phase out."))
		"Vanishing":
			c.enchants(TargetSpec.creature())
			c.activated(ActivatedAbility.new("{U}{U}", false, [F.Action.new(_vanish,
				"enchanted creature phases out", null, true).with_ai_role(&"phase_out_host")],
				"{U}{U}: Enchanted creature phases out."))
		"Time and Tide":
			c.spell(TimeAndTide.new())
		"Equipoise":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _equipoise,
				"At the beginning of your upkeep, for each land target player controls in excess of the number you control, choose a land that player controls, then the chosen permanents phase out. Repeat this process for artifacts and creatures.",
				F._your_upkeep).targeting(TargetSpec.player(), _opponent_first, "Select a player."))
		"Teferi's Realm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _realm,
				"At the beginning of each player's upkeep, that player chooses artifact, creature, land, or non-Aura enchantment. All nontoken permanents of that type phase out."))
		"Vision Charm":
			c.mode("Target player mills four cards", [MillEffect.new(4)])
			c.mode("Choose a land type and a basic land type. Each land of the first chosen type becomes the second chosen type until end of turn",
				[F.Action.new(_retype, "each land of a chosen land type becomes a chosen basic land type until end of turn")])
			c.mode("Target artifact phases out", [PH.PhaseOutTarget.new(TargetSpec.new(
				TargetSpec.Kind.PERMANENT, "target artifact", _artifact).because(TargetSpec.WHY["type"]))])
			c.with_ai_mode(_vision_mode)
		"Katabatic Winds":
			PH.H.phasing(c)
			c.static_ability(StaticAbility.new(_winds,
				"Creatures with flying can't attack or block."))
			c.bans_activations(_winds_ban)
		_:
			return false
	return true


static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)


## Target preference: the other seat's best creature first, our own last.
static func _enemy_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var ia := g.find_instance(a.instance_id)
	var ib := g.find_instance(b.instance_id)
	if ia == null or ib == null: return ia != null
	var mine_a := ia.controller_id == s.controller_id
	var mine_b := ib.controller_id == s.controller_id
	if mine_a != mine_b: return mine_b
	return PH.H.board_value(ia) > PH.H.board_value(ib)


static func _opponent_first(_g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return a.player_id != s.controller_id and b.player_id == s.controller_id


# -------------------------------------------------------- Shimmering Efreet

static func _efreet_shimmer(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t != null and not t.is_player: g.phase_out(g.find_instance(t.instance_id))


# ---------------------------------------------------------------- Vanishing

## "Enchanted creature" is the one the Aura enchanted as the ability was
## activated (the engine records it with the cost), even if the Aura has
## left since (CR 608.2h).
static func _vanish(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var host := g.find_instance(int(g.cost_paid("_source_attached_to", s.attached_to)))
	if host != null and host.layer_timestamp == int(g.cost_paid("_source_attached_timestamp", host.layer_timestamp)):
		g.phase_out(host)


# ------------------------------------------------------------ Time and Tide

## "Simultaneously, all phased-out creatures phase in and all creatures
## with phasing phase out" — one batch (MtgGame.phase_simultaneously). A
## phased-out creature's characteristics are the last ones it had.
class TimeAndTide extends EffectBase:
	func _init() -> void:
		with_ai_role(&"phase_swap")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var outs: Array = []
		for i in g.all_battlefield():
			if i.is_creature() and i.has_keyword(Mtg.Keyword.PHASING): outs.append(i)
		var ins: Array = []
		for i in g.phased_out_permanents():
			if i.is_creature(): ins.append(i)
		g.phase_simultaneously(outs, ins)
	func describe() -> String:
		return "simultaneously, all phased-out creatures phase in and all creatures with phasing phase out"


# ---------------------------------------------------------------- Equipoise

static func _is_land(i: CardInstance) -> bool: return i.is_land()
static func _is_creature(i: CardInstance) -> bool: return i.is_creature()


## Three rounds — lands, then artifacts, then creatures — each counted on
## the board the round before left (a phased-out artifact land is no longer
## an artifact either). The chooser is Equipoise's controller; the hint is
## the target player's best permanents first.
static func _equipoise(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var t := g.current_trigger_target(0)
	if t == null or not t.is_player: return
	var you := PH.H.trigger_pid(g, s)
	var them := t.player_id
	if you == them: return
	for row in [[_is_land, "land"], [_artifact, "artifact"], [_is_creature, "creature"]]:
		var kind: Callable = row[0]
		var theirs: Array = g.players[them].battlefield.filter(kind)
		var excess := theirs.size() - g.players[you].battlefield.filter(kind).size()
		if excess <= 0: continue
		var left := PH.H.best_first(theirs)
		var chosen: Array = []
		for n in excess:
			if left.is_empty(): break
			var pick := g.agents[you].choose_card(g, you, left,
				"Equipoise: choose a %s that player controls to phase out (%d of %d)" % [row[1], n + 1, excess],
				false, false, true)
			if pick == null or not left.has(pick): pick = left[0]
			left.erase(pick)
			chosen.append(pick)
		g.phase_simultaneously(chosen, [])


# ------------------------------------------------------------ Teferi's Realm

static func _realm_filter(i: CardInstance, kind: int) -> bool:
	if i.is_token: return false
	match kind:
		0: return i.is_type(Mtg.CardType.ARTIFACT)
		1: return i.is_creature()
		2: return i.is_land()
		_: return i.is_type(Mtg.CardType.ENCHANTMENT) and not i.is_aura()


## The upkeep player's hint, from the public board. Its own permanents of
## the type are gone through its own turn AND the next (they return at its
## next untap step); the other seat's only for the rest of this turn (they
## return before that seat untaps). So the choice is mostly the type that
## costs the chooser least — the other seat's loss is a small tiebreak.
static func _realm_hint(g: MtgGame, pid: int) -> int:
	var best := 1
	var best_score := -1.0e9
	for kind in REALM_LABELS.size():
		var score := 0.0
		for i in g.all_battlefield():
			if not _realm_filter(i, kind): continue
			score += PH.H.board_value(i) * (0.5 if i.controller_id != pid else -2.0)
		if score > best_score:
			best = kind
			best_score = score
	return best


static func _realm(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("player", g.active_player))
	var kind := g.agents[who].choose_option(g, who, REALM_LABELS,
		"Teferi's Realm: choose artifact, creature, land, or non-Aura enchantment", _realm_hint(g, who))
	if kind < 0 or kind >= REALM_LABELS.size(): kind = _realm_hint(g, who)
	g.log_line("%s chooses %s for Teferi's Realm" % [g.players[who].player_name, REALM_LABELS[kind]])
	var outs: Array = []
	for i in g.all_battlefield():
		if _realm_filter(i, kind): outs.append(i)
	g.phase_simultaneously(outs, [])


# ------------------------------------------------------------- Vision Charm

## Mode 2. CR 611.2c: the lands affected are the lands of the first type as
## it resolves — a land that becomes that type later this turn is not
## included — and each becomes the second type (CR 305.7: it loses its old
## land types and their mana abilities) until end of turn. The hint names
## the type the opponent fields most of and the basic type they field least.
static func _retype(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var counts := {}
	for i in g.all_battlefield():
		if not i.is_land(): continue
		for kind in PH.LAND_TYPES:
			if i.has_subtype(kind):
				counts[kind] = int(counts.get(kind, 0)) + (1 if i.controller_id != pid else -1)
	var first_hint := 0
	for k in PH.LAND_TYPES.size():
		if int(counts.get(PH.LAND_TYPES[k], 0)) > int(counts.get(PH.LAND_TYPES[first_hint], 0)): first_hint = k
	var first := g.agents[pid].choose_option(g, pid, PH.LAND_LABELS, "Vision Charm: choose a land type", first_hint)
	if first < 0 or first >= PH.LAND_TYPES.size(): first = first_hint
	var basics: Array[String] = []
	for k in 5: basics.append(PH.LAND_LABELS[k])
	var second_hint := 0
	for k in 5:
		if k == first: continue
		if second_hint == first or int(counts.get(PH.LAND_TYPES[k], 0)) < int(counts.get(PH.LAND_TYPES[second_hint], 0)):
			second_hint = k
	var second := g.agents[pid].choose_option(g, pid, basics, "Vision Charm: choose a basic land type", second_hint)
	if second < 0 or second >= 5: second = second_hint
	var from := PH.LAND_TYPES[first]
	var to := PH.LAND_TYPES[second]
	g.log_line("Vision Charm: each %s becomes a %s until end of turn" % [PH.LAND_LABELS[first], PH.LAND_LABELS[second]])
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype(from):
			g.continuous.add_floating_static(s, StaticAbility.new(_become.bind(i.id, i.layer_timestamp, to),
				"This land is the chosen basic land type.").changing_land_types(),
				ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()


static func _become(g: MtgGame, _s: CardInstance, id: int, stamp: int, to: String) -> void:
	var i := g.find_instance(id)
	if g.is_present(i) and i.layer_timestamp == stamp:
		i.become_basic_land_type(to, Mtg.BASIC_LAND_COLORS[to])


static func _vision_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].battlefield:
		if _artifact(i) and i.data.cost.mana_value() >= 2: return 2
	return 0


# ---------------------------------------------------------- Katabatic Winds

static func _no_blocks(_i: CardInstance) -> bool: return true


static func _winds(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and i.has_keyword(Mtg.Keyword.FLYING):
			i.cur_cant_attack = true
			i.cur_cant_block_filter = _no_blocks


## "...and their activated abilities with {T} in their costs can't be
## activated" — mana abilities included (CR 605.1a: a Birds of Paradise
## can't tap for mana under the Winds).
static func _winds_ban(_g: MtgGame, _s: CardInstance, _pid: int, inst: CardInstance,
		ability: Variant, _is_mana: bool) -> bool:
	return inst.is_creature() and inst.has_keyword(Mtg.Keyword.FLYING) \
		and MtgGame.ability_has_tap_cost(ability)
