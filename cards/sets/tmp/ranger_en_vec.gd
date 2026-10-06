extends CardScript
## Ranger en-Vec — {1}{G}{W} — Creature — Human Soldier Archer Ranger (uncommon, tmp).
## Oracle: First strike
##         {G}: Regenerate this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ranger en-Vec", "{1}{G}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","soldier","archer","ranger"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\n{G}: Regenerate this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
