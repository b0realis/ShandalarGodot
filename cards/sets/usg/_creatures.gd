extends RefCounted
## Urza's Saga (_creatures, Pack 10). Creatures with activated, static or
## characteristic-defining abilities of their own.
##
## Every listed name implements its whole Oracle text, with a typed effect
## wherever the vocabulary has one (the fair AI reads them —
## engine/ai/effect_intent.gd) and a declared role where an existing
## reading fits the shape (Viashino Sandswimmer's flip, `self_bounce`). The
## scaffolds print what CardData.with_keywords carries; shroud and menace
## are not CardData keywords, so they are layer-6 statics here (Pincher
## Beetles' and Wind Spirit's). tests/cards/test_pack_10_B3_*.gd pin each
## card's distinguishing clause and its edges. Urza's Destiny's creature
## module (cards/sets/uds/_creatures.gd) shares the helpers below.
const F := preload("res://cards/sets/fem/_rules.gd")
const MS := preload("res://cards/sets/mir/_spells.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ---------------------------------------------------------- white
		"Angelic Page":
			# The scaffold prints flying.
			var lift := PumpEffect.new(1, 1)
			lift.target_spec = in_combat_creature()
			c.activated(ActivatedAbility.new("", true, [lift],
				"{T}: Target attacking or blocking creature gets +1/+1 until end of turn."))
		"Elite Archers":
			var shot := DamageEffect.new(3)
			shot.target_spec = in_combat_creature()
			c.activated(ActivatedAbility.new("", true, [shot],
				"{T}: This creature deals 3 damage to target attacking or blocking creature."))
		"Faith Healer":
			# Any enchantment you control, an Aura on an opposing creature
			# included (CR 701.17a: you sacrifice only what you control).
			# The mana value is the sacrificed card's, recorded with the
			# cost (last known information, CR 608.2h).
			c.activated(ActivatedAbility.new("", false, [SacrificedManaValueLife.new()],
				"Sacrifice an enchantment: You gain life equal to the sacrificed enchantment's mana value.") \
				.with_sacrifice_of("enchantment", _enchantment))
		"Intrepid Hero":
			# Power is read live, on activation and again on resolution
			# (CR 608.2b): a Giant Growth makes a bear a legal target.
			c.activated(ActivatedAbility.new("", true,
				[DestroyEffect.new(TargetSpec.creature("target creature with power 4 or greater", _power_four))],
				"{T}: Destroy target creature with power 4 or greater."))
		"Sanctum Custodian":
			# PreventDamageEffect is of the 1997 prevention family (§6.8).
			c.activated(ActivatedAbility.new("", true, [PreventDamageEffect.new(2).any_target()],
				"{T}: Prevent the next 2 damage that would be dealt to any target this turn."))
		"Sanctum Guardian":
			# Circle of Despair's shield (Pack 8), paid with its own body.
			c.activated(ActivatedAbility.new("", false, [SourceShieldEffect.prevent_to_target()],
				"Sacrifice this creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.") \
				.with_sacrifice_cost())
		"Silent Attendant":
			c.activated(ActivatedAbility.new("", true, [GainLifeEffect.new(1)], "{T}: You gain 1 life."))
		"Songstitcher":
			var hush := PreventCombatDamageEffect.new().by_target_creature(
				TargetSpec.creature("target attacking creature with flying", _flying).with_game_filter(_attacking))
			c.activated(ActivatedAbility.new("{1}{W}", false, [hush],
				"{1}{W}: Prevent all combat damage that would be dealt this turn by target attacking creature with flying."))
		# ----------------------------------------------------------- blue
		"Barrin, Master Wizard":
			# The scaffold prints the legendary supertype. "A permanent"
			# includes Barrin himself (may_sacrifice_itself, Hell's
			# Caretaker's shape); the target is chosen before the cost is
			# paid (CR 601.2c, 601.2h).
			c.activated(ActivatedAbility.new("{2}", false, [ReturnToHandEffect.new()],
				"{2}, Sacrifice a permanent: Return target creature to its owner's hand.") \
				.with_sacrifice_of("permanent", _permanent).may_sacrifice_itself())
		"Disruptive Student":
			# Vodalian Mage's toll: the spell's controller is asked as the
			# ability resolves.
			c.activated(ActivatedAbility.new("", true, [F.TollCounter.new("{1}")],
				"{T}: Counter target spell unless its controller pays {1}."))
		"Fog Bank":
			# The scaffold prints defender and flying. Gaseous Form's two
			# combat-only flags, on itself: a Bolt still kills it.
			c.static_ability(StaticAbility.new(_fog_bank,
				"Prevent all combat damage that would be dealt to and dealt by this creature."))
		"Wizard Mentor":
			# The target may be the Mentor itself. With its only target
			# gone the ability does nothing and the Mentor stays (CR 608.2b).
			c.activated(ActivatedAbility.new("", true, [MentorReturn.new()],
				"{T}: Return this creature and target creature you control to their owner's hand."))
		"Zephid":
			# The scaffold prints flying.
			c.static_ability(StaticAbility.new(shroud, "Shroud.").changing_abilities())
		# ---------------------------------------------------------- black
		"Carrion Beetles":
			# Ebony Charm's "up to three target cards from a single
			# graveyard" (Pack 8), on a tap ability.
			c.activated(ActivatedAbility.new("{2}{B}", true, [MS.GraveExile.new()],
				"{2}{B}, {T}: Exile up to three target cards from a single graveyard."))
		"Eastern Paladin":
			c.activated(ActivatedAbility.new("{B}{B}", true,
				[DestroyEffect.new(TargetSpec.creature("target green creature", _green))],
				"{B}{B}, {T}: Destroy target green creature."))
		"Looming Shade":
			c.activated(ActivatedAbility.new("{B}", false, [PumpEffect.new(1, 1).self_buff()],
				"{B}: This creature gets +1/+1 until end of turn."))
		"Phyrexian Ghoul":
			# "A creature" includes the Ghoul itself.
			c.activated(ActivatedAbility.new("", false, [PumpEffect.new(2, 2).self_buff()],
				"Sacrifice a creature: This creature gets +2/+2 until end of turn.") \
				.with_sacrifice_of("creature", F._creature).may_sacrifice_itself())
		"Sanguine Guard":
			# The scaffold prints first strike.
			c.activated(ActivatedAbility.new("{1}{B}", false, [RegenerateEffect.new()], "{1}{B}: Regenerate this creature."))
		"Unworthy Dead":
			c.activated(ActivatedAbility.new("{B}", false, [RegenerateEffect.new()], "{B}: Regenerate this creature."))
		"Western Paladin":
			c.activated(ActivatedAbility.new("{B}{B}", true,
				[DestroyEffect.new(TargetSpec.creature("target white creature", _white))],
				"{B}{B}, {T}: Destroy target white creature."))
		# ------------------------------------------------------------ red
		"Fire Ants":
			c.activated(ActivatedAbility.new("", true, [AntsSweep.new()],
				"{T}: This creature deals 1 damage to each other creature without flying."))
		"Shivan Hellkite":
			# The scaffold prints flying.
			c.activated(ActivatedAbility.new("{1}{R}", false, [DamageEffect.new(1).any_target()],
				"{1}{R}: This creature deals 1 damage to any target."))
		"Viashino Runner":
			c.static_ability(StaticAbility.new(menace, "Menace.").changing_abilities())
		"Viashino Sandswimmer":
			# Role `self_bounce`: the fair AI's answer to an opposing spell
			# aimed at it — won, the creature is back in hand; lost, it is
			# sacrificed; either way the spell finds no target (CR 608.2b).
			c.activated(ActivatedAbility.new("{R}", false,
				[F.Action.new(_sandswimmer,
					"flip a coin: if you win, return this creature to its owner's hand; if you lose, sacrifice it",
					null, true).with_ai_role(&"self_bounce")],
				"{R}: Flip a coin. If you win the flip, return this creature to its owner's hand. If you lose the flip, sacrifice this creature."))
		# ---------------------------------------------------------- green
		"Elvish Herder":
			c.activated(ActivatedAbility.new("{G}", false, [PumpEffect.new(0, 0, [Mtg.Keyword.TRAMPLE])],
				"{G}: Target creature gains trample until end of turn."))
		"Elvish Lyrist":
			c.activated(ActivatedAbility.new("{G}", true,
				[DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _enchantment))],
				"{G}, {T}, Sacrifice this creature: Destroy target enchantment.").with_sacrifice_cost())
		"Hawkeater Moth":
			# The scaffold prints flying.
			c.static_ability(StaticAbility.new(shroud, "Shroud.").changing_abilities())
		"Treefolk Seedlings":
			# A characteristic-defining ability (CR 604.3): it sets the
			# toughness in every zone — the scaffold's printed 0 is the
			# star — and the printed power 2 stands (Uktabi Wildcats' shape).
			c.static_ability(StaticAbility.new(_seedlings,
				"Treefolk Seedlings's toughness is equal to the number of Forests you control.").setting_base_pt())
			c.characteristic_definition = _seedlings
		"Treetop Rangers":
			# Flying only: reach does not let a creature block it.
			c.static_ability(StaticAbility.new(_treetop,
				"This creature can't be blocked except by creatures with flying."))
		_: return false
	return true


# ------------------------------------------------------- shared helpers --

## "Target attacking or blocking creature" (Sawback Manticore's spec).
static func in_combat_creature() -> TargetSpec:
	return TargetSpec.creature("target attacking or blocking creature").with_game_filter(_in_combat)

## Printed shroud: "can't be the target of spells or abilities" (CR 702.18).
static func shroud(_g: MtgGame, s: CardInstance) -> void:
	s.cur_shroud = true

## Printed menace: "can't be blocked except by two or more creatures"
## (CR 702.110).
static func menace(_g: MtgGame, s: CardInstance) -> void:
	s.cur_min_blockers = maxi(s.cur_min_blockers, 2)

## "You" for a characteristic-defining ability: the controller on the
## battlefield or the stack, the owner anywhere else.
static func you(g: MtgGame, s: CardInstance) -> MtgPlayer:
	return g.players[s.controller_id if s.zone == Mtg.Zone.BATTLEFIELD or s.zone == Mtg.Zone.STACK else s.owner_id]


# ------------------------------------------------------------- filters --

static func _in_combat(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) or g.combat.blocks.has(i.id)

static func _attacking(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id)

static func _flying(i: CardInstance) -> bool:
	return i.has_keyword(Mtg.Keyword.FLYING)

static func _enchantment(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ENCHANTMENT)

static func _permanent(_i: CardInstance) -> bool:
	return true

static func _power_four(i: CardInstance) -> bool:
	return i.cur_power >= 4

static func _green(i: CardInstance) -> bool:
	return i.has_color(Mtg.ManaColor.G)

static func _white(i: CardInstance) -> bool:
	return i.has_color(Mtg.ManaColor.W)


# -------------------------------------------------------------- statics --

static func _fog_bank(_g: MtgGame, s: CardInstance) -> void:
	s.cur_prevent_combat_damage_dealt = true
	s.cur_prevent_combat_damage_taken = true

static func _treetop(_g: MtgGame, s: CardInstance) -> void:
	s.cur_block_restrictions.append({"desc": "creatures with flying", "filter": _flying})

## Forests "you" control — a phased-out one is treated as though it does
## not exist (CR 702.26b).
static func _seedlings(g: MtgGame, s: CardInstance) -> void:
	var n := 0
	for i in you(g, s).battlefield:
		if i.is_land() and i.has_subtype("forest") and not i.phased_out:
			n += 1
	s.cur_toughness = n


# -------------------------------------------------------------- actions --

## Viashino Sandswimmer. The coin is flipped whatever happened to the
## creature; the result touches only the object that paid for this
## activation (CR 400.7), and only its controller can sacrifice it
## (CR 701.17a).
static func _sandswimmer(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var won := g.flip_coin(pid)
	if not F._same_activation_source(g, s):
		return
	if won:
		g.return_to_hand(s)
	elif s.controller_id == pid:
		g.sacrifice_permanent(s)


# -------------------------------------------------------------- effects --

## Faith Healer: the life is the sacrificed enchantment's mana value, read
## off THIS activation's cost record (MtgGame.cost_paid — two activations
## waiting at once each gain their own). A GainLifeEffect, so the fair AI
## reads life gain.
class SacrificedManaValueLife extends GainLifeEffect:
	func _init() -> void:
		super(0)

	func resolve(game: MtgGame, _source: CardInstance, controller: int, _target: TargetRef,
			_x_value := 0) -> void:
		var n := int(game.cost_paid("_sacrificed_mana_value", 0))
		if n > 0:
			game.adjust_life(controller, n)

	func describe() -> String:
		return "you gain life equal to the sacrificed enchantment's mana value"


## Wizard Mentor (Snow Hound's shape, Ice Age): the Mentor — the same
## object that was tapped for this — and the target return together.
class MentorReturn extends ReturnToHandEffect:
	func _init() -> void:
		super(TargetSpec.creature("target creature you control").with_source_filter(F._own))

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value := 0) -> void:
		game.begin_simultaneous()
		if F._same_activation_source(game, source):
			game.return_to_hand(source)
		super.resolve(game, source, controller, target, x_value)
		game.end_simultaneous()

	func describe() -> String:
		return "returns this creature and target creature you control to their owner's hand"


## Fire Ants: "each OTHER creature without flying" — the Ants that was
## tapped for this, if it is still that object, is spared; anything else
## that matches is dealt 1, at once (DamageAllEffect's one event). A
## DamageAllEffect, so the fair AI reads the sweep.
class AntsSweep extends DamageAllEffect:
	func _init() -> void:
		super(1, "each other creature without flying", _grounded)

	func resolve(game: MtgGame, source: CardInstance, controller: int, target: TargetRef,
			x_value := 0) -> void:
		var spared: CardInstance = source if F._same_activation_source(game, source) else null
		DamageAllEffect.new(1, description,
			func(i: CardInstance) -> bool: return i != spared and _grounded(i)) \
			.resolve(game, source, controller, target, x_value)

	static func _grounded(i: CardInstance) -> bool:
		return not i.has_keyword(Mtg.Keyword.FLYING)
