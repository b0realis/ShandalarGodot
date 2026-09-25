extends CardScript
## Relentless Assault — {2}{R}{R} — Sorcery (Portal Second Age, 1998).
## Oracle: Untap all creatures that attacked this turn. After this main phase, there is an additional combat phase followed by an additional main phase.

func build() -> CardData:
	var c := CardData.new("Relentless Assault", "{2}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Untap all creatures that attacked this turn. After this main phase, there is an additional combat phase followed by an additional main phase.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
