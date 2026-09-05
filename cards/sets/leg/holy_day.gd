extends CardScript
## Holy Day — {W} — Instant — (leg, common)
## Oracle: Prevent all combat damage that would be dealt this turn.
##
## Implementation: PreventCombatDamageEffect — white's Fog. Both damage
## waves (first strike and regular) are skipped; non-combat damage is
## untouched.


func build() -> CardData:
	return CardData.new("Holy Day", "{W}", Mtg.CardType.INSTANT) \
		.spell(PreventCombatDamageEffect.new()) \
		.oracle("Prevent all combat damage that would be dealt this turn.")
