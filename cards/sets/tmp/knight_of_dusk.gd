extends CardScript
## Knight of Dusk — {1}{B}{B} — Creature — Human Knight (uncommon, tmp).
## Oracle: {B}{B}: Destroy target creature blocking this creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Knight of Dusk", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.oracle("{B}{B}: Destroy target creature blocking this creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
