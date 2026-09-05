extends CardScript
## Xenic Poltergeist — {1}{B}{B} — Creature — Spirit — 1/1 — (4ed, rare)
## Oracle: {T}: Until your next upkeep, target noncreature artifact
##         becomes an artifact creature with power and toughness each
##         equal to its mana value.
##
## Implementation: the ability creates a ONE-SHOT continuous effect with a
## duration of its own (CR 611.2b), registered in the engine's animation
## registry (ContinuousEffects.add_until_eot_animation) rather than as a
## static ability of the Poltergeist. Two consequences the printed card
## demands and a source-bound static could not give: the artifact stays
## animated after the Poltergeist dies, and a second activation animates a
## SECOND artifact instead of releasing the first. Base P/T is the
## artifact's mana value, a printed constant, so it never needs recomputing;
## animating an Ornithopter makes a 0/0 that dies to the toughness
## state-based action at once, exactly as printed.
##
## The duration is the printed one: ContinuousEffects.Duration.UNTIL_UPKEEP_OF
## the ACTIVATOR, which MtgGame ends as their upkeep step begins (CR 611.2b).
## "Your" is the Poltergeist's controller at activation time, not the
## artifact's — so an animated artifact stays a creature through its own
## controller's whole turn.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target noncreature artifact", _is_noncreature_artifact)
	return CardData.new("Xenic Poltergeist", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["spirit"]) \
		.activated(ActivatedAbility.new(
			"", true, [AnimateEffect.new(spec)],
			"{T}: Until your next upkeep, target noncreature artifact becomes an "
			+ "artifact creature with power and toughness each equal to its mana value.")) \
		.oracle("{T}: Until your next upkeep, target noncreature artifact becomes an "
			+ "artifact creature with power and toughness each equal to its mana value.")


static func _is_noncreature_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT) and not inst.is_creature()


class AnimateEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var held := game.find_instance(target.instance_id)
		if held == null or held.zone != Mtg.Zone.BATTLEFIELD:
			return
		# Mana value of the artifact CARD (CR 202.3) — a printed value, so
		# the animation can carry it as a fixed base P/T.
		var mv := held.data.cost.mana_value()
		# It is already an artifact, so only the creature type is granted.
		game.continuous.add_until_eot_animation(held.id, Mtg.CardType.CREATURE,
			mv, mv, [], false,
			ContinuousEffects.Duration.UNTIL_UPKEEP_OF, controller)
		game.recalculate()
		game.check_state_based_actions()

	func describe() -> String:
		return "animates target noncreature artifact until your next upkeep"
