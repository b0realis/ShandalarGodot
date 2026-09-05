extends CardScript
## Sunastian Falconer — {3}{R}{G} — Legendary Creature — Human Shaman — 4/4 — (leg, uncommon)
## Oracle: {T}: Add {C}{C}.
##
## Implementation: a two-colorless ManaAbility (Sol Ring's shape on a 4/4
## body). mage-go models this as a stacked activated ability; CR 605.1a
## makes it a mana ability — no target, no stack — so ours is a
## ManaAbility, which is also what lets it pay for a spell mid-cast.


func build() -> CardData:
	return CardData.new("Sunastian Falconer", "{3}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "shaman"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 2)) \
		.oracle("{T}: Add {C}{C}.")
