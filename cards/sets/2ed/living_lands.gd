extends CardScript
## Living Lands — {3}{G} — Enchantment — (2ed, rare)
## Oracle: All Forests are 1/1 creatures that are still lands.
##
## Implementation: Kormus Bell's green twin (see kormus_bell.gd for the
## mass-animation notes) — every Forest becomes a 1/1 creature land.


func build() -> CardData:
	return CardData.new("Living Lands", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_awaken, "All Forests are 1/1 creatures that are still lands.") \
			.changing_types()) \
		.oracle("All Forests are 1/1 creatures that are still lands.")


static func _awaken(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and inst.has_subtype("forest"):
			inst.cur_types |= Mtg.CardType.CREATURE
			inst.cur_power = 1
			inst.cur_toughness = 1
