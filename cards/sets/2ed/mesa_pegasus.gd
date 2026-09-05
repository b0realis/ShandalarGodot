extends CardScript
## Mesa Pegasus — {1}{W} — Creature — Pegasus — 1/1 (2ed, common)
## Oracle: Flying; banding (Any creatures with banding, and up to one
##         without, can attack in a band. Bands are blocked as a group.)
##
## Implementation: FLYING + BANDING keywords. Band declaration and the
## band-blocking/damage rules live in combat.gd (see its header for the
## documented simplifications, incl. no defensive banding). The classic
## use — banding a big dumb creature with the pegasus so a blocker must
## fight both and the damage lands where the attacker likes — works.


func build() -> CardData:
	return CardData.new("Mesa Pegasus", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["pegasus"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.BANDING]) \
		.oracle("Flying; banding")
