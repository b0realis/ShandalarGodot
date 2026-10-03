extends CardScript
## Uktabi Wildcats — {4}{G} — Creature — Cat (rare, mir).
## Oracle: Uktabi Wildcats's power and toughness are each equal to the number of Forests you control.
##         {G}, Sacrifice a Forest: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Uktabi Wildcats", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["cat"])
	c.oracle("Uktabi Wildcats's power and toughness are each equal to the number of Forests you control.\n{G}, Sacrifice a Forest: Regenerate this creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
