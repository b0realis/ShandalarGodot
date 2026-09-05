extends CardScript
## White Knight — {W}{W} — Creature — Human Knight — 2/2 (2ed, uncommon)
## Oracle: First strike (This creature deals combat damage before creatures
##         without first strike.)
##         Protection from black (This creature can't be blocked, targeted,
##         dealt damage, or enchanted by anything black.)
##
## Implementation: FIRST_STRIKE keyword (two-wave combat in
## MtgGame._combat_damage_step) + protection_from black (the full DEBT bundle:
## Terror can't target it, black creatures can't block it, black damage is
## prevented, black auras fall off). Mirror twin of black_knight.gd.


func build() -> CardData:
	return CardData.new("White Knight", "{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "knight"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.with_protection_from(Mtg.ManaColor.B) \
		.oracle("First strike\nProtection from black")
