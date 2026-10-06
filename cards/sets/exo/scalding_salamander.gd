extends CardScript
## Scalding Salamander — {2}{R} — Creature — Salamander (uncommon, exo).
## Oracle: Whenever this creature attacks, you may have it deal 1 damage to each creature without flying defending player controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scalding Salamander", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["salamander"])
	c.oracle("Whenever this creature attacks, you may have it deal 1 damage to each creature without flying defending player controls.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
