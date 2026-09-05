extends CardScript
## Darkness — {B} — Instant — (leg, common)
## Oracle: Prevent all combat damage that would be dealt this turn.
##
## Implementation: PreventCombatDamageEffect — black's Fog, and the one
## the AI most wants to hold up when it is the defender.


func build() -> CardData:
	return CardData.new("Darkness", "{B}", Mtg.CardType.INSTANT) \
		.spell(PreventCombatDamageEffect.new()) \
		.oracle("Prevent all combat damage that would be dealt this turn.")
