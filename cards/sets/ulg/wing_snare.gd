extends CardScript
## Wing Snare — {2}{G} — Sorcery (uncommon, ulg).
## Oracle: Destroy target creature with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wing Snare", "{2}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target creature with flying.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
