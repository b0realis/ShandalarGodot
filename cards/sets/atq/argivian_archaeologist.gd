extends CardScript
## Argivian Archaeologist — {1}{W}{W} — Creature — Human Artificer — 1/1 — (atq, rare)
## Oracle: {W}{W}, {T}: Return target artifact card from your graveyard to
##         your hand.
##
## Implementation: Reconstruction on a repeatable body — the same filtered
## CARD_IN_YOUR_GRAVEYARD spec, behind {W}{W} and a tap. Against an
## artifact deck this is a one-card engine.


func build() -> CardData:
	var effect := ReturnFromGraveyardEffect.new()
	effect.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
		"target artifact card in your graveyard", _is_artifact)
	return CardData.new("Argivian Archaeologist", "{1}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "artificer"]) \
		.activated(ActivatedAbility.new(
			"{W}{W}", true, [effect],
			"{W}{W}, {T}: Return target artifact card from your graveyard to your hand.")) \
		.oracle("{W}{W}, {T}: Return target artifact card from your graveyard to your hand.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ARTIFACT)
