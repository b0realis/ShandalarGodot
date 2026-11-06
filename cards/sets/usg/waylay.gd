extends CardScript
## Waylay — {2}{W} — Instant (uncommon, usg).
## Oracle: Create three 2/2 white Knight creature tokens. Exile them at the beginning of the next cleanup step.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Waylay", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("Create three 2/2 white Knight creature tokens. Exile them at the beginning of the next cleanup step.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
