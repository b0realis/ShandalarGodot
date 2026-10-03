extends CardScript
## Goblin Recruiter — {1}{R} — Creature — Goblin (uncommon, vis).
## Oracle: When this creature enters, search your library for any number of Goblin cards, reveal them, then shuffle and put those cards on top in any order.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Recruiter", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("When this creature enters, search your library for any number of Goblin cards, reveal them, then shuffle and put those cards on top in any order.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
