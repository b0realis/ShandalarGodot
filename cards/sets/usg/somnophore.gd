extends CardScript
## Somnophore — {2}{U}{U} — Creature — Illusion (rare, usg).
## Oracle: Flying
##         Whenever this creature deals damage to a player, tap target creature that player controls. That creature doesn't untap during its controller's untap step for as long as this creature remains on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Somnophore", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["illusion"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nWhenever this creature deals damage to a player, tap target creature that player controls. That creature doesn't untap during its controller's untap step for as long as this creature remains on the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
