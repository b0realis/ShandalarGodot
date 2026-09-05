extends CardScript
## Karakas — Legendary Land — (leg, uncommon)
## Oracle: {T}: Add {W}.
##         {T}: Return target legendary creature to its owner's hand.
##
## Implementation: a white mana ability plus a filtered ReturnToHandEffect.
## The filter reads the PRINTED supertype (legendary is never granted or
## removed in this pool). Note it hits YOUR legends too — and bouncing
## your own is a real line against a Legend-rule blowout.


func build() -> CardData:
	var bounce := ReturnToHandEffect.new(
		TargetSpec.creature("target legendary creature", _is_legendary))
	return CardData.new("Karakas", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.mana(ManaAbility.new(Mtg.ManaColor.W)) \
		.activated(ActivatedAbility.new(
			"", true, [bounce],
			"{T}: Return target legendary creature to its owner's hand.")) \
		.oracle("{T}: Add {W}.\n{T}: Return target legendary creature to its owner's hand.")


static func _is_legendary(inst: CardInstance) -> bool:
	return (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0
