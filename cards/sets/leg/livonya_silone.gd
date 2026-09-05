extends CardScript
## Livonya Silone — {2}{R}{R}{G}{G} — Legendary Creature — Human Warrior — 4/4 — (leg, rare)
## Oracle: First strike; legendary landwalk
##
## Implementation: printed first strike plus landwalk of the pseudo-type
## "legendary" — CombatState's landwalk check treats that entry as "the
## defender controls a land with the LEGENDARY supertype", so Karakas,
## Urborg, Tolaria, Pendelhaven and The Tabernacle all switch the evasion
## on. In a Legends-heavy field it is a 4/4 first striker that cannot be
## blocked.


func build() -> CardData:
	return CardData.new("Livonya Silone", "{2}{R}{R}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.with_landwalk(["legendary"]) \
		.oracle("First strike; legendary landwalk (This creature can't be blocked as "
			+ "long as defending player controls a legendary land.)")
