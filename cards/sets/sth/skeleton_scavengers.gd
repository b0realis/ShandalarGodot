extends CardScript
## Skeleton Scavengers — {2}{B} — Creature — Skeleton (rare, sth).
## Oracle: This creature enters with a +1/+1 counter on it.
##         Pay {1} for each +1/+1 counter on this creature: Regenerate this creature. When it regenerates this way, put a +1/+1 counter on it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.
## With other regeneration shields up, its controller chooses which one a destruction uses (CR 616.1); the counter comes only with its own (cards/sets/sth/_creatures.gd ScavengerRegeneration).
## SIMPLIFIED (docs/simplified-cards.md, "Skeleton Scavengers"): for lethal combat damage a human seat is not asked — its own shield is used first.

func build() -> CardData:
	var c := CardData.new("Skeleton Scavengers", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["skeleton"])
	c.oracle("This creature enters with a +1/+1 counter on it.\nPay {1} for each +1/+1 counter on this creature: Regenerate this creature. When it regenerates this way, put a +1/+1 counter on it.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
