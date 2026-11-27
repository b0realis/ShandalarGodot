extends CardScript
## Fatal Lore — {2}{B}{B} — Sorcery (rare, all).
## Oracle: An opponent chooses one —
##         • You draw three cards.
##         • You destroy up to two target creatures that player controls. They can't be regenerated. That player draws up to three cards.
## Trusted optional Pack 5 implementation; ZIPs never provide scripts.
## The opponent chooses the mode as the spell is cast (CR 601.2b):
## CardData.opponent_modes, set by the shared handler (_choices.gd).
## SIMPLIFIED (docs/simplified-cards.md, "Fatal Lore"): the caster chooses
## the zero to two creatures on resolution rather than announcement; the
## shared handler also says so in the in-game text.

func build() -> CardData:
	var c := CardData.new("Fatal Lore", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("An opponent chooses one —\n• You draw three cards.\n• You destroy up to two target creatures that player controls. They can't be regenerated. That player draws up to three cards.")
	return load("res://cards/sets/all/_rules.gd").apply(c)
