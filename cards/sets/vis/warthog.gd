extends CardScript
## Warthog — {1}{G}{G} — Creature — Boar (common, vis).
## Oracle: Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Warthog", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 2)
	c.with_subtypes(["boar"])
	c.with_landwalk(["swamp"])
	c.oracle("Swampwalk (This creature can't be blocked as long as defending player controls a Swamp.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
