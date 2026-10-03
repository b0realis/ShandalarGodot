extends CardScript
## Tariff — {1}{W} — Sorcery (rare, wth).
## Oracle: Each player sacrifices the creature they control with the greatest mana value unless they pay that creature's mana cost. If two or more creatures a player controls are tied for greatest, that player chooses one.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tariff", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Each player sacrifices the creature they control with the greatest mana value unless they pay that creature's mana cost. If two or more creatures a player controls are tied for greatest, that player chooses one.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
