extends CardScript
## Benalish Hero — {W} — Creature — Human Soldier — 1/1 (2ed, common)
## Oracle: Banding (Any creatures with banding, and up to one without, can
##         attack in a band. Bands are blocked as a group.)
##
## Implementation: BANDING keyword — the original banding one-drop, and
## the white weenie deck's band-anchor. Rules in combat.gd.


func build() -> CardData:
	return CardData.new("Benalish Hero", "{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "soldier"]) \
		.with_keywords([Mtg.Keyword.BANDING]) \
		.oracle("Banding")
