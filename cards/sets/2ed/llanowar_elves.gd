extends CardScript
## Llanowar Elves — {G} — Creature — Elf Druid — 1/1 (2ed, common)
## Oracle: {T}: Add {G}.
##
## Implementation: a CREATURE with a ManaAbility — the engine's summoning-
## sickness rule for {T} abilities (CR 602.5g) applies automatically, so
## the elves cannot tap the turn they arrive (unlike Sol Ring, whose file
## documents the artifact contrast). The tests pin exactly that.


func build() -> CardData:
	return CardData.new("Llanowar Elves", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["elf", "druid"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("{T}: Add {G}.")
