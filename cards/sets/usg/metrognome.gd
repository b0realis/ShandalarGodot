extends CardScript
## Metrognome — {4} — Artifact (rare, usg).
## Oracle: When a spell or ability an opponent controls causes you to discard this card, create four 1/1 colorless Gnome artifact creature tokens.
##         {4}, {T}: Create a 1/1 colorless Gnome artifact creature token.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Metrognome", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("When a spell or ability an opponent controls causes you to discard this card, create four 1/1 colorless Gnome artifact creature tokens.\n{4}, {T}: Create a 1/1 colorless Gnome artifact creature token.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
