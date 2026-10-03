extends CardScript
## Ethereal Champion — {2}{W}{W}{W} — Creature — Avatar (rare, mir).
## Oracle: Pay 1 life: Prevent the next 1 damage that would be dealt to this creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ethereal Champion", "{2}{W}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["avatar"])
	c.oracle("Pay 1 life: Prevent the next 1 damage that would be dealt to this creature this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
