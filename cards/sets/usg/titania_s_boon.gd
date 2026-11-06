extends CardScript
## Titania's Boon — {3}{G} — Sorcery (uncommon, usg).
## Oracle: Put a +1/+1 counter on each creature you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Titania's Boon", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("Put a +1/+1 counter on each creature you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
