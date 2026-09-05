extends CardScript
## Jacques le Vert — {1}{R}{G}{W} — Legendary Creature — Human Warrior — 3/2 — (leg, rare)
## Oracle: Green creatures you control get +0/+2.
##
## Implementation: a one-sided colour lord. A gold card is EVERY colour in
## its mana cost (CR 105.2b), so Jacques — {1}{R}{G}{W} — is green himself
## and takes the +0/+2 too, ending up a 3/4. mage-go's own test asserts
## the same 3/4. Colour reads the printed cost, the pool-wide convention.


func build() -> CardData:
	return CardData.new("Jacques le Vert", "{1}{R}{G}{W}", Mtg.CardType.CREATURE) \
		.pt(3, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.static_ability(StaticAbility.new(
			_apply, "Green creatures you control get +0/+2.")) \
		.oracle("Green creatures you control get +0/+2.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_creature() \
				and (inst.cur_colors & Mtg.ManaColor.G) != 0:
			inst.cur_toughness += 2
