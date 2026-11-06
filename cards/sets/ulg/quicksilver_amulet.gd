extends CardScript
## Quicksilver Amulet — {4} — Artifact (rare, ulg).
## Oracle: {4}, {T}: You may put a creature card from your hand onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Quicksilver Amulet", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{4}, {T}: You may put a creature card from your hand onto the battlefield.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
