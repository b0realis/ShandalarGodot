extends CardScript
## Walking Sponge — {1}{U} — Creature — Sponge (uncommon, ulg).
## Oracle: {T}: Target creature loses your choice of flying, first strike, or trample until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Walking Sponge", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sponge"])
	c.oracle("{T}: Target creature loses your choice of flying, first strike, or trample until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
