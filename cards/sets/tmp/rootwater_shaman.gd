extends CardScript
## Rootwater Shaman — {2}{U} — Creature — Merfolk Shaman (rare, tmp).
## Oracle: You may cast Aura spells with enchant creature as though they had flash.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Shaman", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["merfolk","shaman"])
	c.oracle("You may cast Aura spells with enchant creature as though they had flash.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
