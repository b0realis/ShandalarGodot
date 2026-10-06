extends CardScript
## Thalakos Dreamsower — {2}{U} — Creature — Thalakos Wizard (uncommon, tmp).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         You may choose not to untap this creature during your untap step.
##         Whenever this creature deals damage to an opponent, tap target creature. That creature doesn't untap during its controller's untap step for as long as this creature remains tapped.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Dreamsower", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["thalakos","wizard"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nYou may choose not to untap this creature during your untap step.\nWhenever this creature deals damage to an opponent, tap target creature. That creature doesn't untap during its controller's untap step for as long as this creature remains tapped.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
