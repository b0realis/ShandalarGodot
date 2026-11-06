extends CardScript
## Dromosaur — {2}{R} — Creature — Dinosaur (common, usg).
## Oracle: Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dromosaur", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["dinosaur"])
	c.oracle("Whenever this creature blocks or becomes blocked, it gets +2/-2 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
