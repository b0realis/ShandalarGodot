extends CardScript
## Sanguine Guard — {1}{B}{B} — Creature — Phyrexian Zombie Knight (uncommon, usg).
## Oracle: First strike
##         {1}{B}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sanguine Guard", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","zombie","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\n{1}{B}: Regenerate this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
