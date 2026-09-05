extends CardScript
## Dakkon Blackblade — {2}{W}{U}{U}{B} — Legendary Creature — Human Warrior — */* — (leg, rare)
## Oracle: Dakkon Blackblade's power and toughness are each equal to the
##         number of lands you control.
##
## Implementation: a dynamic-P/T static (Nightmare's pattern) counting the
## CONTROLLER's lands, both halves SET each recalculation. Printed 0/0, so
## an Armageddon buries him with everything else — and a Living Plane
## turns every land into a creature that Dakkon is already counting.


func build() -> CardData:
	return CardData.new("Dakkon Blackblade", "{2}{W}{U}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Dakkon Blackblade's power and toughness are each equal to the number of "
			+ "lands you control.").setting_base_pt()) \
		.oracle("Dakkon Blackblade's power and toughness are each equal to the number "
			+ "of lands you control.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var lands := 0
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_land():
			lands += 1
	source.cur_power = lands
	source.cur_toughness = lands
