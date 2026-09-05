extends CardScript
## Miracle Worker — {W} — Creature — Human Cleric — 1/1 — (drk, common)
## Oracle: {T}: Destroy target Aura attached to a creature you control.
##
## Implementation: a free tap ability with a game-aware target filter —
## the target must be an Aura whose host is a creature THIS player
## controls, which is checked with a source-aware predicate. Answers
## Paralyze, Weakness and a stolen Control Magic (whose host you control
## while the aura is on it), one per turn, for one white mana.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target Aura attached to a creature you control")
	spec.with_source_filter(_aura_on_your_creature)
	return CardData.new("Miracle Worker", "{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "cleric"]) \
		.activated(ActivatedAbility.new(
			"", true, [DestroyEffect.new(spec)],
			"{T}: Destroy target Aura attached to a creature you control.")) \
		.oracle("{T}: Destroy target Aura attached to a creature you control.")


static func _aura_on_your_creature(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	if not inst.data.is_aura() or inst.attached_to == -1:
		return false
	var host := game.find_instance(inst.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.is_creature() and host.controller_id == source.controller_id
