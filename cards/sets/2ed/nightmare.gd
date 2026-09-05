extends CardScript
## Nightmare — {5}{B} — Creature — Nightmare Horse — */* (2ed, rare)
## Oracle: Flying
##         Nightmare's power and toughness are each equal to the number of
##         Swamps you control.
##
## Implementation: the DYNAMIC-STATS pattern — a static ability on the
## creature itself that SETS cur_power/cur_toughness to the live swamp
## count (by land subtype, so Underground Sea and Bayou feed it) on every
## recalculation. Printed stats are 0/0; characteristic-defining abilities
## like this apply from base values, which our reset-then-apply pipeline
## models naturally. Dies instantly to the toughness<=0 SBA if its
## controller somehow has no swamps — as the real card does.


func build() -> CardData:
	return CardData.new("Nightmare", "{5}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["nightmare", "horse"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.static_ability(StaticAbility.new(
			_apply, "Power and toughness equal to the number of Swamps you control.").setting_base_pt()) \
		.oracle("Flying\nNightmare's power and toughness are each equal to the number of Swamps you control.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var swamps := 0
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_land() and inst.has_subtype("swamp"):
			swamps += 1
	source.cur_power = swamps
	source.cur_toughness = swamps
