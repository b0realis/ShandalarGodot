extends CardScript
## Grindstone — {1} — Artifact (rare, tmp).
## Oracle: {3}, {T}: Target player mills two cards. If two cards that share a color were milled this way, repeat this process.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grindstone", "{1}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Target player mills two cards. If two cards that share a color were milled this way, repeat this process.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
