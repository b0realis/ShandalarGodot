extends CardScript
## Waiting in the Weeds — {1}{G}{G} — Sorcery (rare, mir).
## Oracle: Each player creates a 1/1 green Cat creature token for each untapped Forest they control.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Waiting in the Weeds", "{1}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Each player creates a 1/1 green Cat creature token for each untapped Forest they control.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
