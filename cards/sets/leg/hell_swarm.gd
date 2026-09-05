extends CardScript
## Hell Swarm — {B} — Instant — (leg, common)
## Oracle: All creatures get -1/-0 until end of turn.
##
## Implementation: MassPumpEffect over every creature, both sides — a
## one-mana Marsh Gas that blanks an X/1 alpha strike (or your own
## blockers, so read the board first).


func build() -> CardData:
	return CardData.new("Hell Swarm", "{B}", Mtg.CardType.INSTANT) \
		.spell(MassPumpEffect.new(-1, 0)) \
		.oracle("All creatures get -1/-0 until end of turn.")
