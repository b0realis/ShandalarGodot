extends CardScript
## Volunteer Reserves — {1}{W} — Creature — Human Soldier (uncommon, wth).
## Oracle: Banding (Any creatures with banding, and up to one without, can attack in a band. Bands are blocked as a group. If any creatures with banding you control are blocking or being blocked by a creature, you divide that creature's combat damage, not its controller, among any of the creatures it's being blocked by or is blocking.)
##         Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volunteer Reserves", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["human","soldier"])
	c.with_keywords([Mtg.Keyword.BANDING])
	c.oracle("Banding (Any creatures with banding, and up to one without, can attack in a band. Bands are blocked as a group. If any creatures with banding you control are blocking or being blocked by a creature, you divide that creature's combat damage, not its controller, among any of the creatures it's being blocked by or is blocking.)\nCumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
