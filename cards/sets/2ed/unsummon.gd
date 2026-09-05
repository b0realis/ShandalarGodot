extends CardScript
## Unsummon — {U} — Instant (2ed, common)
## Oracle: Return target creature to its owner's hand.
##
## Implementation: ReturnToHandEffect. Bounce is not destruction — no
## dies-trigger, regeneration irrelevant — and the creature returns to its
## OWNER (matters once control-change effects exist). Any attached auras
## are orphaned and swept to the graveyard by state-based actions, which
## makes Unsummon quiet card advantage against enchanted creatures.


func build() -> CardData:
	return CardData.new("Unsummon", "{U}", Mtg.CardType.INSTANT) \
		.spell(ReturnToHandEffect.new()) \
		.oracle("Return target creature to its owner's hand.")
