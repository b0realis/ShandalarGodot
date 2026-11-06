extends RefCounted
## Urza's Saga (_echo, Pack 10). Echo creatures and permanents (batch B10).
##
## Echo itself is the engine's (EchoAbility, engine/abilities/echo.gd, CR
## 702.30a): one printed triggered ability per card, so a copy has it and
## Humility silences it. Every echo cost in the Urza block equals the mana
## cost; it is written out here as printed.
##
## The rest of each card is composed from the pool's existing pieces, with
## the conventions of the Tempest and Mirage block trigger modules
## (cards/sets/tmp/_triggers.gd, cards/sets/mir/_triggers.gd):
## - an enters (or dies) trigger resolves even when its source has left
##   (CR 603.6 / 608.2h), acting for the seat that controlled it
##   (M.pid_of) and dealing damage from the source as it last existed;
## - a targeted trigger names its target as it goes on the stack (CR
##   603.3d) with a preference order for the heuristic seats: harmful
##   effects the other side's biggest first, helpful ones our own first.
## The shared helpers below are preloaded by cards/sets/ulg/_echo.gd and
## cards/sets/uds/_echo.gd.
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const ETB := Mtg.EventType.ENTERS_BATTLEFIELD

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------- white / red
		"Herald of Serra":      # flying, vigilance (scaffold)
			EchoAbility.attach(c, "{2}{W}{W}")
		"Crater Hellion":
			EchoAbility.attach(c, "{4}{R}{R}")
			c.triggered(TriggeredAbility.new(ETB, _hellion,
				"When this creature enters, it deals 4 damage to each other creature.",
				F._self_enter))
		"Goblin Patrol":
			EchoAbility.attach(c, "{R}")
		"Goblin War Buggy":     # haste (scaffold)
			EchoAbility.attach(c, "{1}{R}")
		"Lightning Dragon":     # flying (scaffold)
			EchoAbility.attach(c, "{2}{R}{R}")
			c.activated(ActivatedAbility.new("{R}", false, [PumpEffect.new(1, 0).self_buff()],
				"{R}: This creature gets +1/+0 until end of turn."))
		"Shivan Raptor":        # first strike, haste (scaffold)
			EchoAbility.attach(c, "{2}{R}")
		"Viashino Outrider":
			EchoAbility.attach(c, "{2}{R}")
		"Vug Lizard":           # mountainwalk (scaffold)
			EchoAbility.attach(c, "{1}{R}{R}")
		# ---------------------------------------------------------- green
		"Acridian":
			EchoAbility.attach(c, "{1}{G}")
		"Albino Troll":
			EchoAbility.attach(c, "{1}{G}")
			c.activated(ActivatedAbility.new("{1}{G}", false, [RegenerateEffect.new()],
				"{1}{G}: Regenerate this creature."))
		"Citanul Centaurs":
			# Shroud is a static the pool writes into cur_shroud (Pincher
			# Beetles, cards/sets/tmp/_creatures.gd): Humility removes it.
			c.static_ability(StaticAbility.new(shroud,
				"Shroud (This creature can't be the target of spells or abilities.)").changing_abilities())
			EchoAbility.attach(c, "{3}{G}")
		"Cradle Guard":         # trample (scaffold)
			EchoAbility.attach(c, "{1}{G}{G}")
		"Pouncing Jaguar":
			EchoAbility.attach(c, "{G}")
		"Winding Wurm":
			EchoAbility.attach(c, "{4}{G}")
		_: return false
	return true


# ------------------------------------------------------------ shared helpers --

static func shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true

## "When this creature enters, draw a card" — the trigger's controller draws.
static func draw_one(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(M.pid_of(g, s), 1)

## "Destroy target …": each still-legal target (the engine has already
## dropped an illegal one, CR 608.2b).
static func destroy_targets(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var victim := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(victim): g.destroy(victim)

## "It deals [param amount] damage to <target>" — from the source as it
## last existed if it has left (CR 608.2h).
static func damage_target(g: MtgGame, s: CardInstance, _e: GameEvent, amount: int) -> void:
	for t in g.current_targets():
		g.deal_damage(s, t as TargetRef, amount)

## "Put a +1/+1 counter on target creature."
static func counter_on_target(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for t in g.current_targets():
		var i := g.find_instance((t as TargetRef).instance_id)
		if g.is_present(i): g.add_counters(i, "+1/+1")

static func make_tokens(g: MtgGame, s: CardInstance, _e: GameEvent, effect: CreateTokenEffect) -> void:
	effect.resolve(g, s, M.pid_of(g, s), null)

## A targeted trigger's preference for a HARMFUL target: the other side's
## first, then the biggest (or costliest) — players before creatures when
## both are allowed and the player is the opponent.
static func theirs_first(g: MtgGame, s: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	var me := g.controller_acting_for(s)
	return _harm_value(g, me, a) > _harm_value(g, me, b)

static func _harm_value(g: MtgGame, me: int, ref: TargetRef) -> int:
	if ref.is_player:
		return 2000 if ref.player_id != me else -2000
	var i := g.find_instance(ref.instance_id)
	if i == null: return -5000
	var v := (1000 if i.controller_id != me else -1000) + i.data.cost.mana_value()
	if i.is_creature(): v += i.cur_power + i.cur_toughness
	return v


# ------------------------------------------------------------ Crater Hellion --

## "Each other creature": every creature on the battlefield as the ability
## resolves except this object, as ONE damage event (DamageAllEffect's
## bracket, CR 704.3) — from the Hellion as it last existed if it is gone.
static func _hellion(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i != s and i.is_creature(): victims.append(i)
	g.begin_simultaneous()
	for v in victims:
		g.deal_damage(s, TargetRef.card(v), 4)
	g.end_simultaneous()
