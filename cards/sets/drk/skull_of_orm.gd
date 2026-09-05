extends CardScript
## Skull of Orm — {3} — Artifact — (drk, uncommon)
## Oracle: {5}, {T}: Return target enchantment card from your graveyard to
##         your hand.
##
## Implementation: a filtered CARD_IN_YOUR_GRAVEYARD ReturnFromGraveyard —
## "your" is engine-enforced, the filter demands an enchantment. Eight
## mana across two turns to rebuy one enchantment; slow, but it makes a
## Disenchant war unwinnable for the other side.


func build() -> CardData:
	var effect := ReturnFromGraveyardEffect.new()
	effect.target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD,
		"target enchantment card in your graveyard", _is_enchantment)
	return CardData.new("Skull of Orm", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{5}", true, [effect],
			"{5}, {T}: Return target enchantment card from your graveyard to your hand.")) \
		.oracle("{5}, {T}: Return target enchantment card from your graveyard to your hand.")


static func _is_enchantment(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ENCHANTMENT)
