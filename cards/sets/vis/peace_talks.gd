extends CardScript
## Peace Talks — {1}{W} — Sorcery (uncommon, vis).
## Oracle: This turn and next turn, creatures can't attack, and players and permanents can't be the targets of spells or activated abilities.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Peace Talks", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("This turn and next turn, creatures can't attack, and players and permanents can't be the targets of spells or activated abilities.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
