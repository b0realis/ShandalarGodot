extends CardScript
## Marsh Gas — {B} — Instant — (4ed, common)
## Oracle: All creatures get -2/-0 until end of turn.
##
## Implementation: MassPumpEffect over EVERY battlefield creature (both
## players — the gas doesn't pick sides). Power may go negative; the
## engine deals no damage for non-positive power.


func build() -> CardData:
	return CardData.new("Marsh Gas", "{B}", Mtg.CardType.INSTANT) \
		.spell(MassPumpEffect.new(-2, 0)) \
		.oracle("All creatures get -2/-0 until end of turn.")
