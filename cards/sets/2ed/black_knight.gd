extends CardScript
## Black Knight — {B}{B} — Creature — Human Knight — 2/2 (2ed, uncommon)
## Oracle: First strike (This creature deals combat damage before creatures
##         without first strike.)
##         Protection from white (This creature can't be blocked, targeted,
##         dealt damage, or enchanted by anything white.)
##
## Implementation: FIRST_STRIKE + protection_from white. Notable pool
## interactions the tests pin: Swords to Plowshares (white) cannot target
## it; Wrath of God still kills it (mass destruction neither targets nor
## damages). Mirror twin of white_knight.gd.


func build() -> CardData:
	return CardData.new("Black Knight", "{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "knight"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.with_protection_from(Mtg.ManaColor.W) \
		.oracle("First strike\nProtection from white")
