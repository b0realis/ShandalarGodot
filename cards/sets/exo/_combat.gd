extends RefCounted
## Exodus (_combat, Pack 9). Combat rules: blocking and attacking restrictions, combat triggers.
##
## - "Becomes blocked by a creature" (Pygmy Troll, Rabid Wolverines) hears
##   BLOCKED — one event per blocking creature, so two blockers are two
##   triggers (CR 509.3d); "becomes blocked" alone (Elvish Berserker) is
##   BECOMES_BLOCKED, once, and counts its blockers as it resolves
##   (CR 509.3c, 608.2h).
## - "Attacks alone" (Reckless Ogre) is the only creature declared as an
##   attacker that combat (CR 506.5).
## - Crashing Boars' "that creature blocks this creature this turn if able"
##   is a Lure narrowed to the creature the DEFENDING player chose
##   (Marble Priest's shape), kept by a floating static bound to the Boars
##   for the turn; a Lure already asking every creature is left alone.
## - Exalted Dragon's land is an attack cost paid as attackers are declared
##   (CR 508.1g, cur_attack_land_sacrifices): the engine asks which land.
## - Wall of Nets: the end-of-combat trigger exiles what the Wall blocked
##   and links those cards to THIS Wall (its memory, per exile visit, so a
##   card that left exile and came back is a new object — CR 400.7); the
##   leaves-the-battlefield trigger returns exactly those under their
##   OWNERS' control (CR 610.3c reads the link from the departing Wall).
## tests/cards/test_pack_9_B12_combat.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Cinder Crawler":
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn. Activate only if this creature is blocked.").only_if(_is_blocked))
		"Crashing Boars":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _boars,
				"Whenever this creature attacks, defending player chooses an untapped creature they control. That creature blocks this creature this turn if able.",
				F._self_attack))
		"Elven Palisade":
			var shrink := PumpEffect.new(-3, 0)
			shrink.target_spec = TargetSpec.creature("target attacking creature").with_game_filter(_attacking).because("attacking")
			c.activated(ActivatedAbility.new("", false, [shrink],
				"Sacrifice a Forest: Target attacking creature gets -3/-0 until end of turn.").with_sacrifice_of("Forest", _forest))
		"Elvish Berserker":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _berserker,
				"Whenever this creature becomes blocked, it gets +1/+1 until end of turn for each creature blocking it.", F._self_enter))
		"Exalted Dragon":
			c.static_ability(StaticAbility.new(_dragon_toll, "This creature can't attack unless you sacrifice a land."))
		"High Ground":
			c.static_ability(StaticAbility.new(_high_ground, "Each creature you control can block an additional creature each combat."))
		"Monstrous Hound":
			c.static_ability(StaticAbility.new(_hound,
				"This creature can't attack unless you control more lands than defending player. This creature can't block unless you control more lands than attacking player."))
		"Pygmy Troll":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _grow,
				"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.", _blocked_by_creature))
			c.activated(ActivatedAbility.new("{G}", false, [RegenerateEffect.new()], "{G}: Regenerate this creature."))
		"Rabid Wolverines":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _grow,
				"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.", _blocked_by_creature))
		"Reckless Ogre":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _ogre,
				"Whenever this creature attacks alone, it gets +3/+0 until end of turn.", _attacks_alone))
		"Reconnaissance":
			c.activated(ActivatedAbility.new("", false, [Recall.new()],
				"{0}: Remove target attacking creature you control from combat and untap it."))
		"Scalding Salamander":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _salamander,
				"Whenever this creature attacks, you may have it deal 1 damage to each creature without flying defending player controls.",
				F._self_attack))
		"Wall of Nets":
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT, _nets_exile,
				"At end of combat, exile all creatures blocked by this creature.", _nets_blocked))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _nets_release,
				"When this creature leaves the battlefield, return all cards exiled with it to the battlefield under their owners' control.",
				F._self_enter))
		_: return false
	return true


static func _anything(_i: CardInstance) -> bool: return true
static func _forest(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("forest")
static func _attacking(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _you(g: MtgGame, s: CardInstance) -> int:
	return int(g.trigger_context(s).get("controller", s.controller_id))

static func _land_count(g: MtgGame, pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): n += 1
	return n


# ---------------------------------------------------------- Cinder Crawler --

## "Activate only if this creature is blocked": an attacking creature that
## became blocked this combat stays blocked (CR 509.1h).
static func _is_blocked(g: MtgGame, s: CardInstance) -> String:
	return "" if g.combat.blocked_attackers.has(s.id) else "activate only if this creature is blocked"


# ---------------------------------------------------------- Crashing Boars --

## The DEFENDING player chooses (the Boars' controller's opponent — the
## player it attacks in a two-seat duel). Their candidates come ranked for
## them, public board only: one that can't legally block the Boars at all
## first, then one that survives it (and kills it), then the cheapest.
static func _boars(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var defender := g.opponent_of(_you(g, s))
	var cards: Array[CardInstance] = []
	for i in g.players[defender].battlefield:
		if i.is_creature() and not i.tapped: cards.append(i)
	if cards.is_empty(): return
	cards.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var sa := _boars_rank(g, s, a, defender)
		var sb := _boars_rank(g, s, b, defender)
		return sa > sb if sa != sb else a.id < b.id)
	var pick := g.agents[defender].choose_card(g, defender, cards,
		"Crashing Boars: choose an untapped creature you control to block it", false, false, true)
	if pick == null or not cards.has(pick): pick = cards[0]
	g.log_line("%s chooses %s to block Crashing Boars" % [g.players[defender].player_name, pick.data.card_name])
	g.continuous.add_floating_static(s, StaticAbility.new(_boars_lure.bind(s.layer_timestamp, pick.id, pick.layer_timestamp),
		"That creature blocks this creature this turn if able."),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()

static func _boars_rank(g: MtgGame, boars: CardInstance, i: CardInstance, defender: int) -> int:
	if CombatState.block_illegality(g, i, boars, defender) != "": return 3000
	var survives := i.cur_toughness - i.damage > boars.cur_power
	var kills := i.cur_power >= boars.cur_toughness - boars.damage
	if survives: return 2000 + (500 if kills else 0) + i.cur_power
	return 1000 - maxi(i.cur_power, 0) - maxi(i.cur_toughness, 0) - i.data.cost.mana_value()

static func _boars_lure(g: MtgGame, s: CardInstance, stamp: int, id: int, chosen_stamp: int) -> void:
	if not g.is_present(s) or s.layer_timestamp != stamp: return
	if s.cur_must_be_blocked_by_all or (s.cur_must_be_blocked and not s.cur_must_be_blocked_filter.is_valid()): return
	var before := s.cur_must_be_blocked_filter
	var chosen := func(blocker: CardInstance) -> bool:
		return blocker.id == id and blocker.layer_timestamp == chosen_stamp
	s.cur_must_be_blocked = true
	if not before.is_valid():
		s.cur_must_be_blocked_filter = chosen
	else:
		s.cur_must_be_blocked_filter = func(blocker: CardInstance) -> bool:
			return bool(before.call(blocker)) or bool(chosen.call(blocker))


# -------------------------------------------------------- Elvish Berserker --

static func _berserker(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var n := g.combat.blockers_of(s.id).size()
	if n <= 0: return
	g.continuous.add_until_eot_pump(s.id, n, n)
	g.recalculate()


# ----------------------------------------------------------- Exalted Dragon --

static func _dragon_toll(_g: MtgGame, s: CardInstance) -> void:
	s.cur_attack_land_sacrifices += 1


# ------------------------------------------------------------- High Ground --

static func _high_ground(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and i.cur_extra_blocks >= 0: i.cur_extra_blocks += 1


# ----------------------------------------------------------- Monstrous Hound --

## Two seats: the defending player and the attacking player are both the
## Hound's controller's opponent.
static func _hound(g: MtgGame, s: CardInstance) -> void:
	var mine := _land_count(g, s.controller_id)
	var theirs := _land_count(g, g.opponent_of(s.controller_id))
	if mine <= theirs:
		s.cur_cant_attack = true
		s.cur_cant_block_filter = _anything


# ------------------------------------------ Pygmy Troll / Rabid Wolverines --

static func _blocked_by_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("attacker") == s and e.data.get("blocker") != null

static func _grow(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.continuous.add_until_eot_pump(s.id, 1, 1)
	g.recalculate()


# ------------------------------------------------------------ Reckless Ogre --

static func _attacks_alone(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var attackers: Array = e.data.get("attackers", [])
	return attackers.size() == 1 and attackers[0] == s

static func _ogre(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	g.continuous.add_until_eot_pump(s.id, 3, 0)
	g.recalculate()


# ----------------------------------------------------------- Reconnaissance --

## "Remove target attacking creature you control from combat and untap it."
class Recall extends UntapEffect:
	func _init() -> void:
		super(TargetSpec.creature("target attacking creature you control") \
			.with_game_filter(_attacking_creature).with_source_filter(_own).because("attacking"))
		ai_helpful = true
	static func _attacking_creature(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
	static func _own(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s != null and i.controller_id == g.controller_acting_for(s)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g.remove_from_combat(i)
		g.untap_permanent(i)
	func describe() -> String:
		return "remove target attacking creature you control from combat and untap it"


# ------------------------------------------------------ Scalding Salamander --

## The Salamander deals the damage — as it last existed if it has left
## (CR 608.2h) — to every creature without flying the defending player
## controls as the ability resolves, at once (one damage event).
static func _salamander(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := _you(g, s)
	var defender := g.opponent_of(pid)
	var victims: Array[CardInstance] = []
	for i in g.players[defender].battlefield:
		if i.is_creature() and not i.has_keyword(Mtg.Keyword.FLYING): victims.append(i)
	if victims.is_empty(): return
	if not g.agents[pid].choose_yes_no(g, pid,
			"Scalding Salamander: deal 1 damage to each creature without flying the defending player controls?", true):
		return
	g.begin_simultaneous()
	for i in victims: g.deal_damage(s, TargetRef.card(i), 1)
	g.end_simultaneous()


# ------------------------------------------------------------- Wall of Nets --

static func _nets_blocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return g.is_present(s) and not g.combat.attackers_blocked_by(s.id).is_empty()

## "Exile all creatures blocked by this creature": what the Wall blocks as
## the ability resolves (an attacker removed from combat is no longer
## blocked by it). The cards are linked to the Wall only while it is still
## the object that triggered; a Wall gone by then already had its
## leaves-the-battlefield trigger, so nothing will bring them back.
static func _nets_exile(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var victims: Array[CardInstance] = []
	for id in g.combat.attackers_blocked_by(s.id):
		var i := g.find_instance(id)
		if g.is_present(i) and i.is_creature(): victims.append(i)
	if victims.is_empty(): return
	var linked := F._same_trigger_source(g, s)
	var netted: Array = (s.memory.get("netted", []) as Array).duplicate() if linked else []
	for i in victims:
		g.exile_permanent(i)
		if i.zone == Mtg.Zone.EXILE and not i.is_token:
			netted.append([i.id, i.exile_entry])
	if linked and g.is_present(s):
		g._rec(s, &"memory")
		s.memory["netted"] = netted

## The departing Wall's memory snapshot travels with the event.
static func _nets_release(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var memory: Dictionary = e.data.get("memory", {})
	for row in memory.get("netted", []):
		var i := g.find_instance(int(row[0]))
		if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(row[1]):
			g.return_from_exile_to_play(i, i.owner_id)
