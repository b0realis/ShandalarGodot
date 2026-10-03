extends RefCounted
## Mirage (_combat, Pack 8). Combat rules: flanking, blocking and attacking restrictions, combat triggers.
##
## Conventions every handler here keeps (the Visions module,
## cards/sets/vis/_combat.gd, shares the helpers at the bottom):
## - FLANKING is the engine's (Pack 8 E2, engine/abilities/flanking.gd): a
##   printed knight carries the keyword ([method flanking]) and the engine
##   puts one real stack trigger per instance per non-flanking blocker.
##   Cards only READ it ("has flanking" = has_keyword) or take it away
##   (add_until_eot_loss); a grant is never deduplicated.
## - "Blocks or becomes blocked by <a creature>" hears BLOCKED, which the
##   engine dispatches once per blocking creature per attacker — for every
##   member of a band whose blocker it is (CR 702.22h) and for a block an
##   effect makes (MtgGame.set_block). "Becomes blocked" by an effect with
##   no creature (Dazzling Beauty) is BECOMES_BLOCKED alone (CR 509.3c-d).
##   The other creature is captured as the ability triggers (id and
##   timestamp) and acted on only while it is that same object (CR 400.7).
## - "Blocks or becomes blocked" with no creature named hears
##   BECOMES_BLOCKER / BECOMES_BLOCKED, once each.
## - "Whenever a creature attacks" is one trigger PER CREATURE (CR 603.2c,
##   508.3a); the engine announces a declaration once, so an off-stack
##   listener ([method attack_fan_out]) puts one real trigger per
##   attacking creature on the stack.
## - A triggered ability resolves even when its source has left (CR 603.6,
##   608.2h); only "it"/"this creature" clauses check that the same object
##   is still there (F._same_trigger_source). "Defending player" is the
##   active player's opponent while combat lasts (CR 506.2).
const F := preload("res://cards/sets/fem/_rules.gd")

const EITHER := 0       # "blocks or becomes blocked by"
const BLOCKED_BY := 1   # "becomes blocked by" — this creature attacks
const BLOCKS := 2       # "blocks" — this creature blocks


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Alarum": c.spell(Alarum.new())
		"Dazzling Beauty":
			c.castable_only_when(_during_declare_blockers)
			c.spell(MakeBlockedEffect.new()).spell(DelayedDrawEffect.new(1))
		"Divine Retribution": c.spell(Retribution.new())
		"Femeref Knight":
			flanking(c)
			c.activated(ActivatedAbility.new("{W}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.VIGILANCE]).self_buff()],
				"{W}: This creature gains vigilance until end of turn."))
		"Mtenda Herder": flanking(c)
		"Sidar Jabari":
			flanking(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, tap_target,
				"Whenever Sidar Jabari attacks, tap target creature defending player controls.",
				F._self_attack).targeting(P.defending_creature_spec(), P.untapped_biggest_first,
				"Select a creature defending player controls to tap."))
		"Sunweb": c.static_ability(StaticAbility.new(_sunweb, "This creature can't block creatures with power 2 or less."))
		"Yare": c.spell(Yare.new())
		"Zhalfirin Commander":
			flanking(c)
			c.activated(ActivatedAbility.new("{1}{W}{W}", false, [P.knight_pump()],
				"{1}{W}{W}: Target Knight creature gets +1/+1 until end of turn."))
		"Zhalfirin Knight":
			flanking(c)
			c.activated(ActivatedAbility.new("{W}{W}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()],
				"{W}{W}: This creature gains first strike until end of turn."))
		# ------------------------------------------------------------- blue
		"Coral Fighters":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _coral_fighters,
				"Whenever this creature attacks and isn't blocked, look at the top card of defending player's library. You may put that card on the bottom of that player's library.",
				F._self_enter))
		"Kukemssa Pirates":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, _pirates,
				"Whenever this creature attacks and isn't blocked, you may gain control of target artifact defending player controls. If you do, this creature assigns no combat damage this turn.",
				F._self_enter).targeting(P.defending_artifact_spec(), P.biggest_first,
				"Select an artifact defending player controls."))
		# ------------------------------------------------------------ black
		"Cadaverous Knight":
			flanking(c)
			c.activated(ActivatedAbility.new("{1}{B}{B}", false, [RegenerateEffect.new()],
				"{1}{B}{B}: Regenerate this creature."))
		"Catacomb Dragon":
			c.triggered(pair_trigger(BLOCKED_BY, P.nonartifact_non_dragon, _dragon_shrink,
				"Whenever this creature becomes blocked by a nonartifact, non-Dragon creature, that creature gets -X/-0 until end of turn, where X is half the creature's power, rounded down."))
		"Crypt Cobra":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, poison_defender,
				"Whenever this creature attacks and isn't blocked, defending player gets a poison counter.",
				F._self_enter))
		"Dread Specter":
			c.triggered(pair_trigger(EITHER, P.nonblack, doom_other,
				"Whenever this creature blocks or becomes blocked by a nonblack creature, destroy that creature at end of combat."))
		# -------------------------------------------------------------- red
		"Aleatory":
			c.castable_only_when(_after_blockers)
			c.spell(Aleatory.new()).spell(DelayedDrawEffect.new(1))
		"Barreling Attack": c.spell(BarrelingAttack.new())
		"Blind Fury": c.spell(BlindFury.new())
		"Burning Shield Askari":
			flanking(c)
			c.activated(ActivatedAbility.new("{R}{R}", false,
				[PumpEffect.new(0, 0, [Mtg.Keyword.FIRST_STRIKE]).self_buff()],
				"{R}{R}: This creature gains first strike until end of turn."))
		"Crimson Roc":
			c.triggered(pair_trigger(BLOCKS, P.without_flying, _roc,
				"Whenever this creature blocks a creature without flying, this creature gets +1/+0 and gains first strike until end of turn."))
		"Ekundu Cyclops": c.static_ability(CombatState.attacks_with_others())
		"Goblin Elite Infantry":
			self_combat_pump(c, -1, -1, "Whenever this creature blocks or becomes blocked, it gets -1/-1 until end of turn.")
		"Searing Spear Askari":
			flanking(c)
			c.activated(ActivatedAbility.new("{1}{R}", false,
				[F.Action.new(_menace_self, "this creature gains menace until end of turn", null, true)],
				"{1}{R}: This creature gains menace until end of turn. (It can't be blocked except by two or more creatures.)"))
		"Telim'Tor":
			flanking(c)
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _telim_tor,
				"Whenever Telim'Tor attacks, all attacking creatures with flanking get +1/+1 until end of turn.",
				F._self_attack))
		# ------------------------------------------------------------ green
		"Barbed Foliage":
			c.triggered(attack_fan_out(_foliage_fan_out, _attacks_controller,
				"Whenever a creature attacks you, it loses flanking until end of turn. Whenever a creature without flying attacks you, this enchantment deals 1 damage to it."))
		"Brushwagg":
			self_combat_pump(c, -2, 2, "Whenever this creature blocks or becomes blocked, it gets -2/+2 until end of turn.")
		"Gibbering Hyenas":
			c.static_ability(StaticAbility.new(_hyenas, "This creature can't block black creatures."))
		"Jolrael's Centaur":
			flanking(c)
			c.static_ability(StaticAbility.new(_shroud, "Shroud."))
		"Jungle Wurm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, _jungle_wurm,
				"Whenever this creature becomes blocked, it gets -1/-1 until end of turn for each creature blocking it beyond the first.",
				F._self_enter))
		"Mindbender Spores":
			c.triggered(pair_trigger(BLOCKS, Callable(), _spores,
				"Whenever this creature blocks a creature, put four fungus counters on that creature. The creature gains \"This creature doesn't untap during your untap step if it has a fungus counter on it\" and \"At the beginning of your upkeep, remove a fungus counter from this creature.\""))
		"Mtenda Lion":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _mtenda_lion,
				"Whenever this creature attacks, defending player may pay {U}. If that player does, prevent all combat damage that would be dealt by this creature this turn.",
				F._self_attack))
		"Sabertooth Cobra":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _cobra_bite,
				"Whenever this creature deals damage to a player, that player gets a poison counter. The player gets another poison counter at the beginning of their next upkeep unless they pay {2} before that step.",
				_hits_a_player).capturing(_bite_context))
		# ------------------------------------------------------------- gold
		"Delirium":
			c.castable_only_when(_opponents_turn)
			c.spell(Delirium.new())
		"Harbor Guardian":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _harbor_guardian,
				"Whenever this creature attacks, defending player may draw a card.", F._self_attack))
		"Rock Basilisk":
			c.triggered(pair_trigger(EITHER, P.non_wall, doom_other,
				"Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat."))
		# -------------------------------------------------------- artifacts
		"Basalt Golem":
			c.static_ability(StaticAbility.new(_basalt_unblockable, "This creature can't be blocked by artifact creatures."))
			c.triggered(pair_trigger(BLOCKED_BY, Callable(), _basalt_doom,
				"Whenever this creature becomes blocked by a creature, that creature's controller sacrifices it at end of combat. If the player does, they create a 0/2 colorless Wall artifact creature token with defender."))
		"Lead Golem":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _lead_golem,
				"Whenever this creature attacks, it doesn't untap during its controller's next untap step.",
				F._self_attack))
		_: return false
	return true


# ============================================================ shared helpers

## Printed flanking (CR 702.25a). The scaffold could not print the keyword
## before engine package E2 existed; the trigger itself is the engine's.
static func flanking(c: CardData) -> void:
	if not c.keywords.has(Mtg.Keyword.FLANKING):
		c.with_keywords([Mtg.Keyword.FLANKING])


## The seat an ability is acting for as it resolves (CR 603.3a).
static func pid_of(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id


## The defending player (CR 506.2): the active player's opponent.
static func defender(g: MtgGame) -> int:
	return g.opponent_of(g.active_player)


## The very object that triggered, still on the battlefield (CR 400.7).
static func same(g: MtgGame, s: CardInstance) -> bool:
	return g.is_present(s) and F._same_trigger_source(g, s)


## An activated ability's source is still the object that paid its cost.
static func live_source(g: MtgGame, s: CardInstance) -> bool:
	return g.is_present(s) \
		and s.layer_timestamp == int(g.cost_paid("_source_timestamp", s.layer_timestamp))


## The other creature of a BLOCKED pair [param s] is on [param side] of,
## or null.
static func pair_other(s: CardInstance, e: GameEvent, side: int) -> CardInstance:
	var attacker: CardInstance = e.data.get("attacker")
	var blocker: CardInstance = e.data.get("blocker")
	if side != BLOCKS and attacker == s:
		return blocker
	if side != BLOCKED_BY and blocker == s:
		return attacker
	return null


## Trigger condition: [param s] is on [param side] of the pair and the
## other creature passes [param filter] (read as the block happens).
static func pair_meets(_g: MtgGame, s: CardInstance, e: GameEvent, side: int, filter: Callable) -> bool:
	var other := pair_other(s, e, side)
	return other != null and (not filter.is_valid() or bool(filter.call(other)))


## Per-occurrence context: the source as it triggered and the OTHER
## creature's identity, captured as the ability triggers.
static func pair_context(_g: MtgGame, s: CardInstance, e: GameEvent, side: int) -> Dictionary:
	var other := pair_other(s, e, side)
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"other": other.id if other != null else -1,
		"other_stamp": other.layer_timestamp if other != null else -1}


## The other creature of the resolving pair trigger, while it is still the
## same object on the battlefield; null otherwise.
static func pair_other_live(g: MtgGame, s: CardInstance) -> CardInstance:
	var ctx := g.trigger_context(s)
	var other := g.find_instance(int(ctx.get("other", -1)))
	if not g.is_present(other) or other.layer_timestamp != int(ctx.get("other_stamp", -2)):
		return null
	return other


## A BLOCKED trigger for one side of the pair.
static func pair_trigger(side: int, filter: Callable, resolve: Callable, text: String) -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.BLOCKED, resolve, text,
		pair_meets.bind(side, filter)).capturing(pair_context.bind(side))


## "Destroy that creature at end of combat" (the basilisk gaze — Thicket
## Basilisk's pattern, 2ed/thicket_basilisk.gd): queued in the engine's
## end-of-combat doom list; regeneration applies.
static func doom_other(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := pair_other_live(g, s)
	if other != null:
		g.doom_at_end_of_combat(other)


## "Whenever this creature blocks or becomes blocked, it gets +P/+T until
## end of turn" — one trigger for each half.
static func self_combat_pump(c: CardData, power: int, toughness: int, text: String) -> void:
	for type in [Mtg.EventType.BECOMES_BLOCKER, Mtg.EventType.BECOMES_BLOCKED]:
		c.triggered(TriggeredAbility.new(type, _self_pump.bind(power, toughness), text, F._self_enter))


static func _self_pump(g: MtgGame, s: CardInstance, _e: GameEvent, power: int, toughness: int) -> void:
	if not same(g, s):
		return
	g.continuous.add_until_eot_pump(s.id, power, toughness)
	g.recalculate()


## "This creature assigns no combat damage this turn" (Kukemssa Pirates,
## Dwarven Vigilantes, Pygmy Hippo): a floating static on that object.
static func assigns_no_combat_damage(g: MtgGame, s: CardInstance) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_no_damage.bind(s.id),
		"Assigns no combat damage this turn."), ContinuousEffects.Duration.END_OF_TURN,
		-1, false, s.id)
	g.recalculate()


static func _no_damage(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if g.is_present(i):
		i.cur_assigns_no_combat_damage = true


## "Defending player gets a poison counter" (Crypt Cobra, Suq'Ata Assassin).
static func poison_defender(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	g.add_poison(defender(g))


## "Tap target creature" (Sidar Jabari).
static func tap_target(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var i := g.find_instance(t.instance_id)
		if g.is_present(i):
			g.tap_permanent(i)


## "Can't block <attackers>" composed with whatever "can't block" filter
## another effect already wrote (the field holds one Callable).
static func cant_block(s: CardInstance, filter: Callable) -> void:
	var before := s.cur_cant_block_filter
	if not before.is_valid():
		s.cur_cant_block_filter = filter
		return
	s.cur_cant_block_filter = func(attacker: CardInstance) -> bool:
		return bool(before.call(attacker)) or bool(filter.call(attacker))


## THE PER-CREATURE FAN-OUT. "Whenever a creature attacks" triggers once
## for each creature declared as an attacker (CR 603.2c, 508.3a), but the
## engine announces a declaration as ONE event (DECLARED_ATTACKERS). This
## listener rides the dispatcher's off-stack path (as_mana_trigger: it
## runs as the event is dispatched and never sits on the stack — the path
## Rowen's reveal and Debt of Loyalty's control change take) and puts one
## real triggered ability per attacking creature on the stack with
## MtgGame.queue_reflexive_trigger, so each can be answered on its own.
## [param fan] is func(game, source, event) -> void.
static func attack_fan_out(fan: Callable, condition: Callable, text: String) -> TriggeredAbility:
	return TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, fan, text, condition) \
		.capturing(F._source_context).as_mana_trigger()


## One per-creature trigger for [param attacker] (see [method attack_fan_out]):
## [param resolve] is called (game, source, event, attacker id, attacker
## timestamp, *[param extra]).
static func queue_for_attacker(g: MtgGame, s: CardInstance, e: GameEvent, pid: int,
		attacker: CardInstance, resolve: Callable, text: String, extra: Array = []) -> void:
	var args: Array = [attacker.id, attacker.layer_timestamp]
	args.append_array(extra)
	var trigger := TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS,
		resolve.bindv(args), text).capturing(F._source_context)
	g.queue_reflexive_trigger(trigger, pid, s, e)


## The creature a per-creature trigger was for, while it is that object.
static func live(g: MtgGame, id: int, stamp: int) -> CardInstance:
	var i := g.find_instance(id)
	return i if g.is_present(i) and i.layer_timestamp == stamp else null


static func _attacks_controller(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return g.active_player != s.controller_id


# ======================================================== predicates/specs

class P:
	static func nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0
	static func black(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) != 0
	static func non_wall(i: CardInstance) -> bool: return not i.has_subtype("wall")
	static func without_flying(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)
	static func flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
	static func knight(i: CardInstance) -> bool: return i.has_subtype("knight")
	static func artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	static func nonartifact(i: CardInstance) -> bool: return not i.is_type(Mtg.CardType.ARTIFACT)
	static func nonartifact_non_dragon(i: CardInstance) -> bool:
		return not i.is_type(Mtg.CardType.ARTIFACT) and not i.has_subtype("dragon")

	## "Creature defending player controls" — a property of the COMBAT
	## (CR 506.2): there is a defending player only while combat lasts.
	static func defending(g: MtgGame, i: CardInstance) -> bool:
		return Mtg.is_combat_step(g.current_step()) and i.controller_id == g.opponent_of(g.active_player)

	static func nonattacking(g: MtgGame, i: CardInstance) -> bool:
		return not g.combat.attackers.has(i.id)

	static func defending_creature_spec() -> TargetSpec:
		return TargetSpec.creature("target creature defending player controls") \
			.with_game_filter(defending).because(TargetSpec.WHY["controller"])

	static func defending_artifact_spec() -> TargetSpec:
		return TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact defending player controls",
			artifact).with_game_filter(defending)

	static func knight_pump() -> PumpEffect:
		var pump := PumpEffect.new(1, 1)
		pump.target_spec = TargetSpec.creature("target Knight creature", knight)
		return pump

	## A harmful trigger target: the opponent's, untapped, biggest first.
	static func untapped_biggest_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
		var me := g.controller_acting_for(s)
		var ai := g.find_instance(a.instance_id)
		var bi := g.find_instance(b.instance_id)
		if ai == null or bi == null: return ai != null
		var av := (1000 if ai.controller_id != me else 0) + (100 if not ai.tapped else 0) + ai.cur_power + ai.cur_toughness
		var bv := (1000 if bi.controller_id != me else 0) + (100 if not bi.tapped else 0) + bi.cur_power + bi.cur_toughness
		return av > bv

	## The opponent's first, the biggest (or costliest) first.
	static func biggest_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
		var me := g.controller_acting_for(s)
		var ai := g.find_instance(a.instance_id)
		var bi := g.find_instance(b.instance_id)
		if ai == null or bi == null: return ai != null
		var av := (1000 if ai.controller_id != me else 0) + ai.data.cost.mana_value() + ai.cur_power + ai.cur_toughness
		var bv := (1000 if bi.controller_id != me else 0) + bi.data.cost.mana_value() + bi.cur_power + bi.cur_toughness
		return av > bv


# ================================================================== white

## Alarum: "Untap target nonattacking creature. It gets +1/+3 until end of
## turn." One target, both sentences.
class Alarum extends PumpEffect:
	func _init() -> void:
		super(1, 3)
		target_spec = TargetSpec.creature("target nonattacking creature") \
			.with_game_filter(P.nonattacking).because("attacking")
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g.untap_permanent(i)
		super(g, s, pid, t, x)
	func describe() -> String:
		return "untap target nonattacking creature; it gets +1/+3 until end of turn"


## Cast only in the declare blockers step (Dazzling Beauty, CR 509).
static func _during_declare_blockers(g: MtgGame, _pid: int) -> String:
	return "" if g.current_step() == Mtg.Step.DECLARE_BLOCKERS else "cast only during the declare blockers step"


## Divine Retribution: the count is taken as it resolves.
class Retribution extends DamageEffect:
	func _init() -> void:
		super(1)
		target_spec = MakeBlockedEffect.attacker_spec()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var attackers := 0
		for id in g.combat.attackers:
			if g.is_present(g.find_instance(int(id))): attackers += 1
		if attackers > 0: g.deal_damage(s, t, attackers)
	func describe() -> String:
		return "deal damage to target attacking creature equal to the number of attacking creatures"


static func _sunweb(_g: MtgGame, s: CardInstance) -> void:
	cant_block(s, _power_two_or_less)


static func _power_two_or_less(attacker: CardInstance) -> bool:
	return attacker.cur_power <= 2


## Yare: +3/+0, and "can block up to two additional creatures this turn"
## (CR 509.1b) — the turn-scoped permission Blaze of Glory uses
## (CardInstance.extra_blocks_this_turn, cleared at cleanup), added to.
class Yare extends PumpEffect:
	func _init() -> void:
		super(3, 0)
		target_spec = P.defending_creature_spec()
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		super(g, s, pid, t, x)
		if i.extra_blocks_this_turn >= 0:
			g._rec(i, &"extra_blocks_this_turn")
			i.extra_blocks_this_turn += 2
	func describe() -> String:
		return "target creature defending player controls gets +3/+0 and can block up to two additional creatures this turn"


# =================================================================== blue

## Coral Fighters: the trigger's controller looks (a private reveal to
## that seat only) and decides; the hint buries a spell and keeps a land
## on top — public to that seat now, nothing else is read.
static func _coral_fighters(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := pid_of(g, s)
	var foe := defender(g)
	var library := g.players[foe].library
	if library.is_empty(): return
	var top: CardInstance = library.back()
	g.reveal_information(pid, "Coral Fighters — the top of %s's library" % g.players[foe].player_name,
		[top.data.card_name])
	if g.agents[pid].choose_yes_no(g, pid, "Put %s on the bottom of %s's library?" % [
			top.data.card_name, g.players[foe].player_name], not top.data.is_land()):
		g.put_on_bottom_of_library(top)


static func _pirates(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var loot := g.find_instance(targets[0].instance_id)
	if not g.is_present(loot): return
	var pid := pid_of(g, s)
	if not g.agents[pid].choose_yes_no(g, pid,
			"Gain control of %s? Kukemssa Pirates then assigns no combat damage this turn." % loot.data.card_name, true):
		return
	g.change_control(loot, pid)
	if loot.controller_id == pid and same(g, s):
		assigns_no_combat_damage(g, s)


# ================================================================== black

static func _dragon_shrink(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := pair_other_live(g, s)
	if other == null: return
	# Half its power as the ability resolves, rounded down; a negative X is
	# 0 (CR 107.1b).
	var x := maxi(0, floori(other.cur_power / 2.0))
	if x <= 0: return
	g.continuous.add_until_eot_pump(other.id, -x, 0)
	g.recalculate()


# ==================================================================== red

## "Cast only during combat after blockers are declared" (Aleatory): the
## declare-blockers step once the declaration is made, and the combat
## steps after it — of a combat in which creatures attacked (with none,
## there is no declare-blockers step at all, CR 508.8).
static func _after_blockers(g: MtgGame, _pid: int) -> String:
	var step := g.current_step()
	var after := (step == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers) \
		or step in [Mtg.Step.FIRST_STRIKE_DAMAGE, Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]
	if not after or g.combat.participant_stamps.is_empty():
		return "cast only during combat after blockers are declared"
	return ""


## Aleatory: the flip is the caster's, as the spell resolves (CR 705).
class Aleatory extends PumpEffect:
	func _init() -> void:
		super(1, 1)
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if not g.is_present(g.find_instance(t.instance_id)): return
		if g.flip_coin(pid):
			super(g, s, pid, t, x)
	func describe() -> String:
		return "flip a coin; if you win, target creature gets +1/+1 until end of turn"


## Barreling Attack: trample now, and a delayed "when that creature
## becomes blocked this turn" (CR 603.7) that counts its blockers as it
## resolves — a band's blockers block every member (CR 702.22h).
class BarrelingAttack extends PumpEffect:
	func _init() -> void:
		super(0, 0, [Mtg.Keyword.TRAMPLE])
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		super(g, s, pid, t, x)
		var trigger := TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED,
			_barreling.bind(i.id, i.layer_timestamp),
			"When that creature becomes blocked this turn, it gets +1/+1 until end of turn for each creature blocking it.",
			_that_creature.bind(i.id, i.layer_timestamp))
		var entry := g.schedule_delayed_trigger(trigger, pid, s)
		entry["expires_turn"] = g.turn_number
	func describe() -> String:
		return "target creature gains trample until end of turn; when it becomes blocked this turn it gets +1/+1 for each creature blocking it"
	static func _that_creature(_g: MtgGame, _s: CardInstance, e: GameEvent, id: int, stamp: int) -> bool:
		var i: CardInstance = e.data.get("instance")
		return i != null and i.id == id and i.layer_timestamp == stamp
	static func _barreling(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
		var i := g.find_instance(id)
		if not g.is_present(i) or i.layer_timestamp != stamp: return
		var n := g.combat.blockers_of_band(g.combat.band_of(id)).size()
		if n <= 0: return
		g.continuous.add_until_eot_pump(id, n, n)
		g.recalculate()


## Blind Fury: the creatures on the battlefield as it resolves lose
## trample (CR 611.2c); the doubling is a damage MODIFIER for this turn's
## combat damage dealt by a creature to a creature (Pack 8 E5, CR 614.1a),
## which the affected creature's controller orders against prevention
## (CR 616.1).
class BlindFury extends EffectBase:
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for i in g.all_battlefield():
			if i.is_creature():
				g.continuous.add_until_eot_loss(i.id, [Mtg.Keyword.TRAMPLE])
		g.recalculate()
		g.add_damage_effect({"kind": &"modify", "factor": 2, "combat_only": true,
			"controller": pid, "card": "Blind Fury",
			"desc": "Blind Fury: combat damage a creature deals to a creature is doubled",
			"filter": _creature_to_creature})
	func describe() -> String:
		return "all creatures lose trample until end of turn; combat damage creatures deal to creatures this turn is doubled"
	static func _creature_to_creature(_g: MtgGame, p: DamagePacket) -> bool:
		return p.source != null and p.source.is_creature() and not p.target.is_player


static func _roc(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not same(g, s): return
	g.continuous.add_until_eot_pump(s.id, 1, 0, [Mtg.Keyword.FIRST_STRIKE])
	g.recalculate()


## Searing Spear Askari: menace is an ability (layer 6) on this object for
## the turn — "can't be blocked except by two or more creatures".
static func _menace_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not live_source(g, s): return
	g.continuous.add_floating_static(s, StaticAbility.new(_menace.bind(s.id),
		"Menace (can't be blocked except by two or more creatures).").changing_abilities(),
		ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.recalculate()


static func _menace(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if g.is_present(i):
		i.cur_min_blockers = maxi(i.cur_min_blockers, 2)


## Telim'Tor: "has flanking" is read as the ability resolves.
static func _telim_tor(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for id in g.combat.attackers:
		var i := g.find_instance(int(id))
		if g.is_present(i) and i.has_keyword(Mtg.Keyword.FLANKING):
			g.continuous.add_until_eot_pump(i.id, 1, 1)
	g.recalculate()


# ================================================================== green

## Barbed Foliage's two "whenever a creature attacks you" abilities, one
## trigger each per attacking creature ([method attack_fan_out]). "Without
## flying" is read as the creature attacks.
static func _foliage_fan_out(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := s.controller_id
	for attacker in e.data.get("attackers", []):
		var i := attacker as CardInstance
		if i == null: continue
		queue_for_attacker(g, s, e, pid, i, _foliage_unflank,
			"Whenever a creature attacks you, it loses flanking until end of turn.")
		if not i.has_keyword(Mtg.Keyword.FLYING):
			queue_for_attacker(g, s, e, pid, i, _foliage_sting,
				"Whenever a creature without flying attacks you, this enchantment deals 1 damage to it.")


static func _foliage_unflank(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := live(g, id, stamp)
	if i == null: return
	g.continuous.add_until_eot_loss(i.id, [Mtg.Keyword.FLANKING])
	g.recalculate()


static func _foliage_sting(g: MtgGame, s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := live(g, id, stamp)
	if i != null:
		g.deal_damage(s, TargetRef.card(i), 1)


static func _hyenas(_g: MtgGame, s: CardInstance) -> void:
	cant_block(s, P.black)


static func _shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true


## Jungle Wurm — rampage turned around; the blockers are counted as the
## ability resolves (CR 608.2h), a band's blockers being every member's.
static func _jungle_wurm(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not same(g, s): return
	var extra := g.combat.blockers_of_band(g.combat.band_of(s.id)).size() - 1
	if extra <= 0: return
	g.continuous.add_until_eot_pump(s.id, -extra, -extra)
	g.recalculate()


## Mindbender Spores: four counters and two GRANTED abilities that stay
## with that creature (no duration: CR 611.2a's "indefinitely"), carried
## by a floating layer-6 static bound to it — the Musician's shape
## (cards/sets/ice/_permanents.gd). Every block grants them again: a
## second set is a second upkeep trigger.
static func _spores(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := pair_other_live(g, s)
	if other == null: return
	g.add_counters(other, "fungus", 4)
	var upkeep := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _fungus_upkeep,
		"At the beginning of your upkeep, remove a fungus counter from this creature.",
		F._your_upkeep).capturing(F._source_context)
	g.continuous.add_floating_static(s, StaticAbility.new(_fungus_grants.bind(other.id, other.layer_timestamp, upkeep),
		"This creature doesn't untap during your untap step if it has a fungus counter on it.") \
		.changing_abilities().granting_triggers([Mtg.EventType.UPKEEP_START]),
		ContinuousEffects.Duration.INDEFINITE, -1, false, other.id)
	g.recalculate()


static func _fungus_grants(g: MtgGame, _s: CardInstance, id: int, stamp: int, upkeep: TriggeredAbility) -> void:
	var i := g.find_instance(id)
	if not g.is_present(i) or i.layer_timestamp != stamp or i.cur_abilities_silenced: return
	i.cur_triggered_abilities.append(upkeep)
	if int(i.counters.get("fungus", 0)) > 0:
		i.cur_skips_untap = true


static func _fungus_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if same(g, s) and int(s.counters.get("fungus", 0)) > 0:
		g.remove_counters(s, "fungus", 1)


## Mtenda Lion: the DEFENDING player's choice (CR 118.12), offered while
## the Lion is still the creature that attacked.
static func _mtenda_lion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not same(g, s): return
	var foe := defender(g)
	if EffectBase.unless_paid(g, foe, ManaCost.parse("{U}"),
			"Pay {U} to prevent all combat damage Mtenda Lion would deal this turn?", true):
		g.continuous.add_until_eot_combat_prevention(s.id, true, false)
		g.recalculate()


## Sabertooth Cobra (Nafs Asp's shape, 4ed/nafs_asp.gd; Pack 8 E10): the
## second counter is a delayed trigger at the bitten player's next upkeep
## that they may pay off ({2}, MtgGame.settle_delayed_trigger) any time
## they hold priority BEFORE that step — once it has triggered it is too
## late, so the trigger itself offers no payment.
static func _hits_a_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("source") == s and e.data.has("to_player") and int(e.data.get("amount", 0)) > 0


static func _bite_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"victim": int(e.data.get("to_player", -1))}


static func _cobra_bite(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var victim := int(g.trigger_context(s).get("victim", -1))
	if victim < 0: return
	g.add_poison(victim, 1)
	var entry := g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START,
		_cobra_poison.bind(victim),
		"At the beginning of the bitten player's next upkeep, they get a poison counter.",
		_upkeep_of.bind(victim)), pid_of(g, s), s, false, {},
		"Sabertooth Cobra: pay {2} before your next upkeep or get a poison counter")
	entry["settle_cost"] = ManaCost.parse("{2}")
	entry["settle_by"] = victim


static func _upkeep_of(_g: MtgGame, _s: CardInstance, e: GameEvent, who: int) -> bool:
	return int(e.data.get("player", -1)) == who


static func _cobra_poison(g: MtgGame, _s: CardInstance, _e: GameEvent, who: int) -> void:
	g.add_poison(who, 1)


# =================================================================== gold

static func _opponents_turn(g: MtgGame, pid: int) -> String:
	return "" if g.active_player != pid else "cast only during an opponent's turn"


## Delirium: "that player" is the opponent whose turn it is; the creature
## is the source of the damage to its controller (CR 120.3), and then
## neither deals nor is dealt combat damage this turn.
class Delirium extends TapEffect:
	func _init() -> void:
		super(TargetSpec.creature("target creature that player controls").with_source_filter(_theirs)
			.because(TargetSpec.WHY["controller"]))
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if not g.is_present(i): return
		g.tap_permanent(i)
		var power := maxi(0, i.cur_power)
		if power > 0:
			g.deal_damage(i, TargetRef.player(i.controller_id), power)
		if g.is_present(i):
			g.continuous.add_until_eot_combat_prevention(i.id, true, true)
			g.recalculate()
	func describe() -> String:
		return "tap target creature the active opponent controls; it deals damage equal to its power to that player; prevent all combat damage to and by it this turn"
	static func _theirs(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return i.controller_id == g.active_player and g.active_player != g.controller_acting_for(s)


## Harbor Guardian: the DEFENDING player's "may".
static func _harbor_guardian(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var foe := defender(g)
	if g.agents[foe].choose_yes_no(g, foe, "Harbor Guardian attacks: draw a card?", true):
		g.draw_cards(foe, 1)


# ============================================================== artifacts

static func _basalt_unblockable(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "nonartifact creatures", "filter": P.nonartifact})


## Basalt Golem: the sacrifice is a DELAYED trigger at end of combat (CR
## 603.7), by whoever controls that creature then (CR 701.17a); the Wall
## comes only if they did sacrifice it.
static func _basalt_doom(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var other := pair_other_live(g, s)
	if other == null: return
	var trigger := TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_basalt_sacrifice.bind(other.id, other.layer_timestamp),
		"At end of combat, that creature's controller sacrifices it. If the player does, they create a 0/2 colorless Wall artifact creature token with defender.")
	var entry := g.schedule_delayed_trigger(trigger, pid_of(g, s), s)
	entry["expires_turn"] = g.turn_number


static func _basalt_sacrifice(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := live(g, id, stamp)
	if i == null: return
	var who := i.controller_id
	g.sacrifice_permanent(i)
	if i.zone == Mtg.Zone.BATTLEFIELD and not i.phased_out: return
	var wall := CardData.new("Wall", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(0, 2).with_subtypes(["wall"]).with_keywords([Mtg.Keyword.DEFENDER])
	g.create_token(who, wall)


static func _lead_golem(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if same(g, s):
		g.skip_untap_during_next_step(s, s.controller_id)
