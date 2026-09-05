extends CardScript
## Elvish Archers — {1}{G} — Creature — Elf Archer — 2/1 (2ed, rare)
## Oracle: First strike
##
## Implementation: plain first strike on an efficient body — included as
## the mono-keyword FIRST_STRIKE creature (the Knights bundle it with
## protection), so combat-wave tests have a clean subject.


func build() -> CardData:
	return CardData.new("Elvish Archers", "{1}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 1) \
		.with_subtypes(["elf", "archer"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.oracle("First strike")
