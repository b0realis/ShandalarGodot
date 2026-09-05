extends CardScript
## Reconstruction — {U} — Sorcery — (atq, common)
## Oracle: Return target artifact card from your graveyard to your hand.
##
## Implementation: ReturnFromGraveyardEffect aimed at a filtered
## CARD_IN_YOUR_GRAVEYARD spec — "your" is enforced by the engine against
## the spell's owner, the filter demands an artifact. One blue mana to
## rebuy the artifact a Shatterstorm just took.


func build() -> CardData:
	var effect := ReturnFromGraveyardEffect.new()
	effect.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
		"target artifact card in your graveyard", _is_artifact)
	return CardData.new("Reconstruction", "{U}", Mtg.CardType.SORCERY) \
		.spell(effect) \
		.oracle("Return target artifact card from your graveyard to your hand.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ARTIFACT)
