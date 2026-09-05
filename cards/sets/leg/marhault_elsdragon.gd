extends CardScript
## Marhault Elsdragon — {3}{R}{R}{G} — Legendary Creature — Elf Warrior — 4/6 — (leg, uncommon)
## Oracle: Rampage 1 (Whenever this creature becomes blocked, it gets
##         +1/+1 until end of turn for each creature blocking it beyond
##         the first.)
##
## Implementation: the engine's RAMPAGE field. A legendary 4/6 whose
## rampage is small enough that the body, not the keyword, is the point.


func build() -> CardData:
	return CardData.new("Marhault Elsdragon", "{3}{R}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(4, 6) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elf", "warrior"]) \
		.with_rampage(1) \
		.oracle("Rampage 1 (Whenever this creature becomes blocked, it gets +1/+1 "
			+ "until end of turn for each creature blocking it beyond the first.)")
