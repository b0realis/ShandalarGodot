extends CardScript
## Scrapheap — {3} — Artifact (rare, ulg).
## Oracle: Whenever an artifact or enchantment is put into your graveyard from the battlefield, you gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scrapheap", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("Whenever an artifact or enchantment is put into your graveyard from the battlefield, you gain 1 life.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
