extends CardScript
## Peregrine Drake — {4}{U} — Creature — Drake (uncommon, usg).
## Oracle: Flying
##         When this creature enters, untap up to five lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Peregrine Drake", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhen this creature enters, untap up to five lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
