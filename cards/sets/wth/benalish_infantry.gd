extends CardScript
## Benalish Infantry — {2}{W} — Creature — Human Soldier (common, wth).
## Oracle: Banding (Any creatures with banding, and up to one without, can attack in a band. Bands are blocked as a group. If any creatures with banding you control are blocking or being blocked by a creature, you divide that creature's combat damage, not its controller, among any of the creatures it's being blocked by or is blocking.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Benalish Infantry", "{2}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.BANDING])
	c.oracle("Banding (Any creatures with banding, and up to one without, can attack in a band. Bands are blocked as a group. If any creatures with banding you control are blocking or being blocked by a creature, you divide that creature's combat damage, not its controller, among any of the creatures it's being blocked by or is blocking.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
