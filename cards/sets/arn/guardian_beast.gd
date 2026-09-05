extends CardScript
## Guardian Beast — {3}{B} — Creature — Beast — 2/4 — (arn, rare)
## Oracle: As long as this creature is untapped, noncreature artifacts you
##         control can't be enchanted, they have indestructible, and other
##         players can't gain control of them. This effect doesn't remove
##         Auras already attached to those artifacts.
##
## Implementation: a conditional static — the whole clause switches off the
## moment the Beast taps, which is why it is famously answered by an Icy
## Manipulator. All three protections are engine flags:
## cur_cant_be_aura_target (Steal Artifact and Power Artifact can no longer
## be cast at them), cur_indestructible, and cur_cant_change_control, which
## MtgGame.change_control honours — the one door every control change goes
## through, so Gauntlets of Chaos cannot trade one away either.
##
## "This effect doesn't remove Auras already attached" is free here: the
## state-based Aura check asks TargetSpec.can_attach_to, which reads what
## the host IS, and the engine's separate cur_cant_be_aura_target flag is
## consulted only when an Aura would newly target it. An Animate Artifact
## already on a Mishra's Factory stays put.
##
## NOTE the printed word "noncreature": an Ornithopter you control is not
## protected, and neither is the Beast itself.


func build() -> CardData:
	return CardData.new("Guardian Beast", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["beast"]) \
		.static_ability(StaticAbility.new(
			_guard, "As long as this creature is untapped, noncreature artifacts you control can't be enchanted, have indestructible, and can't change controllers.")) \
		.oracle("As long as this creature is untapped, noncreature artifacts you control "
			+ "can't be enchanted, they have indestructible, and other players can't gain "
			+ "control of them. This effect doesn't remove Auras already attached to those "
			+ "artifacts.")


static func _guard(game: MtgGame, source: CardInstance) -> void:
	if source.tapped:
		return
	for inst in game.players[source.controller_id].battlefield:
		if not inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature():
			continue
		inst.cur_cant_be_aura_target = true
		inst.cur_indestructible = true
		inst.cur_cant_change_control = true
