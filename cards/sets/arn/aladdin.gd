extends CardScript
## Aladdin — {2}{R}{R} — Creature — Human Rogue — 1/1 — (arn, rare)
## Oracle: {1}{R}{R}, {T}: Gain control of target artifact for as long as
##         you control this creature.
##
## Implementation: MtgGame.gain_control_leashed with the Aladdin as the
## leash and no tapped requirement — the engine's state-based check hands
## the artifact back the moment Aladdin leaves the battlefield. Repeatable
## once per untap, so a patient Aladdin can strip a whole artifact deck.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)
	return CardData.new("Aladdin", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "rogue"]) \
		.activated(ActivatedAbility.new(
			"{1}{R}{R}", true, [StealEffect.new(spec)],
			"{1}{R}{R}, {T}: Gain control of target artifact for as long as you "
			+ "control Aladdin.")) \
		.oracle("{1}{R}{R}, {T}: Gain control of target artifact for as long as you "
			+ "control this creature.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


class StealEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var prize := game.find_instance(target.instance_id)
		if prize != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(prize, source, false)

	func describe() -> String:
		return "gain control of %s while you control this" % target_spec.description
