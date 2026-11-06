extends CardScript
## Phyrexian Processor — {4} — Artifact (rare, usg).
## Oracle: As this artifact enters, pay any amount of life.
##         {4}, {T}: Create an X/X black Phyrexian Minion creature token, where X is the life paid as this artifact entered.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Processor", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("As this artifact enters, pay any amount of life.\n{4}, {T}: Create an X/X black Phyrexian Minion creature token, where X is the life paid as this artifact entered.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
