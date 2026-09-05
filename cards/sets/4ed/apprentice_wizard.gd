extends CardScript
## Apprentice Wizard — {1}{U}{U} — Creature — Human Wizard — 0/1 — (4ed, common)
## Oracle: {U}, {T}: Add {C}{C}{C}.
##
## Implementation: a COSTED mana ability ({U} paid from the floating pool,
## like Celestial Prism's) — net +2 colourless a turn once it survives a
## turn cycle. Being a creature its {T} is gated by summoning sickness
## (CR 602.5g).


func build() -> CardData:
	return CardData.new("Apprentice Wizard", "{1}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["human", "wizard"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 3).with_mana_cost("{U}")) \
		.oracle("{U}, {T}: Add {C}{C}{C}.")
