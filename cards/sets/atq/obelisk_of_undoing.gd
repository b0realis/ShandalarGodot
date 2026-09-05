extends CardScript
## Obelisk of Undoing — {1} — Artifact — (atq, rare)
## Oracle: {6}, {T}: Return target permanent you both own and control to
##         your hand.
##
## Implementation: a ReturnToHandEffect with a source-aware filter
## demanding the target be both OWNED and CONTROLLED by the activator —
## so a stolen permanent can't be rescued and theirs can't be bounced.
## Six mana to rebuy an enters-the-battlefield effect.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target permanent you both own and control")
	spec.with_source_filter(_yours_entirely)
	return CardData.new("Obelisk of Undoing", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{6}", true, [ReturnToHandEffect.new(spec)],
			"{6}, {T}: Return target permanent you both own and control to your hand.")) \
		.oracle("{6}, {T}: Return target permanent you both own and control to your hand.")


static func _yours_entirely(_game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.owner_id == source.controller_id \
		and inst.controller_id == source.controller_id
