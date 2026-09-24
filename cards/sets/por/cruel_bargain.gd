extends CardScript
## Cruel Bargain — {B}{B}{B} — Sorcery (Portal, 1997).
## Oracle: Draw four cards. You lose half your life, rounded up.

func build() -> CardData:
	var c := CardData.new("Cruel Bargain", "{B}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Draw four cards. You lose half your life, rounded up.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
