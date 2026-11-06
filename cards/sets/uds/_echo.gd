extends RefCounted
## Urza's Destiny (_echo, Pack 10). Echo creatures and permanents (batch B10).
## Echo is EchoAbility (engine/abilities/echo.gd, CR 702.30a); the shared
## helpers and conventions are cards/sets/usg/_echo.gd's (U).
##
## "When this creature enters or dies" is ONE printed ability listening to
## two events (TriggeredAbility.also_when): a dying creature hears its own
## death with the abilities it had as it left (CR 603.10a), and its
## controller then is the trigger's (CR 603.3a). Letting Goblin Marshal's
## echo go is a sacrifice, so it dies: two more Goblins. A dying Hunting
## Moa can't target itself — it is in the graveyard by then.
const U := preload("res://cards/sets/usg/_echo.gd")
const F := preload("res://cards/sets/fem/_rules.gd")
const M := preload("res://cards/sets/mir/_triggers.gd")
const ETB := Mtg.EventType.ENTERS_BATTLEFIELD

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Goblin Marshal":
			EchoAbility.attach(c, "{4}{R}{R}")
			c.triggered(TriggeredAbility.new(ETB,
				U.make_tokens.bind(CreateTokenEffect.new("Goblin", 1, 1, Mtg.ManaColor.R, "goblin", 2)),
				"When this creature enters or dies, create two 1/1 red Goblin creature tokens.",
				F._self_enter).also_when(Mtg.EventType.DIES))
		"Keldon Champion":      # haste (scaffold)
			EchoAbility.attach(c, "{2}{R}{R}")
			c.triggered(TriggeredAbility.new(ETB, U.damage_target.bind(3),
				"When this creature enters, it deals 3 damage to target player or planeswalker.",
				F._self_enter).targeting(TargetSpec.player(), U.theirs_first,
					"Keldon Champion: choose a player to deal 3 damage to."))
		"Keldon Vandals":
			EchoAbility.attach(c, "{2}{R}")
			c.triggered(TriggeredAbility.new(ETB, U.destroy_targets,
				"When this creature enters, destroy target artifact.",
				F._self_enter).targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact",
					_artifact), U.theirs_first, "Keldon Vandals: choose an artifact to destroy."))
		"Hunting Moa":
			EchoAbility.attach(c, "{2}{G}")
			c.triggered(TriggeredAbility.new(ETB, U.counter_on_target,
				"When this creature enters or dies, put a +1/+1 counter on target creature.",
				F._self_enter).also_when(Mtg.EventType.DIES).targeting(TargetSpec.creature(),
					M.friendly_first, "Hunting Moa: choose a creature to get a +1/+1 counter."))
		"Extruder":
			EchoAbility.attach(c, "{4}")
			# "Sacrifice an artifact" — an artifact creature, it may be
			# its own cost.
			c.activated(ActivatedAbility.new("", false,
				[CounterMarkerEffect.new("+1/+1", 1, TargetSpec.creature())],
				"Sacrifice an artifact: Put a +1/+1 counter on target creature.") \
				.with_sacrifice_of("artifact", _artifact).may_sacrifice_itself())
		_: return false
	return true


static func _artifact(i: CardInstance) -> bool:
	return i.is_type(Mtg.CardType.ARTIFACT)
