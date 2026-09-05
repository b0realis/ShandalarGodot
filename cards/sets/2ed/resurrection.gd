extends CardScript
## Resurrection — {2}{W}{W} — Sorcery — (2ed, uncommon)
## Oracle: Return target creature card from your graveyard to the battlefield.
##
## Implementation: white's clean reanimation — ReturnFromGraveyardEffect
## in battlefield mode (MtgGame.reanimate under the caster), restricted to
## YOUR graveyard by the target kind. No drawback, no aura to protect —
## unlike Animate Dead the creature stays if nothing else kills it.
## mage-go: TargetCreatureInYourGraveyard + ReturnFromGraveyardToBattlefield.


func build() -> CardData:
	return CardData.new("Resurrection", "{2}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(ReturnFromGraveyardEffect.new().to_battlefield()) \
		.oracle("Return target creature card from your graveyard to the battlefield.")
