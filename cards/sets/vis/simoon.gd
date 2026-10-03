extends CardScript
## Simoon — {R}{G} — Instant (uncommon, vis).
## Oracle: Simoon deals 1 damage to each creature target opponent controls.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Simoon", "{R}{G}", Mtg.CardType.INSTANT)
	c.oracle("Simoon deals 1 damage to each creature target opponent controls.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
