extends CardScript
## Living Lands — {3}{G} — Enchantment — (2ed, rare)
## Oracle: All Forests are 1/1 creatures that are still lands.
##
## Implementation: Kormus Bell's green twin (see kormus_bell.gd for the
## mass-animation notes) — one effect, keyed "living_lands"
## ([method StaticAbility.part_of]), in two layers: every Forest becomes a
## creature that is still a land in layer 4, and those Forests have base
## power and toughness 1/1 in layer 7b, in timestamp order with the other 7b
## setters (CR 613.4b, 613.7; gap review 2026-11-10, r2-4 — the 1/1 used to
## be written in layer 4, where an older Verdant Touch's 2/2 overwrote it).

const KEY := &"living_lands"


func build() -> CardData:
	return CardData.new("Living Lands", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_awaken, "All Forests are creatures that are still lands.") \
			.changing_types().part_of(KEY)) \
		.static_ability(StaticAbility.new(
			_size, "The Forests it animates have base power and toughness 1/1.") \
			.setting_base_pt().part_of(KEY)) \
		.oracle("All Forests are 1/1 creatures that are still lands.")


## Layer 4: every Forest is a creature that is still a land.
static func _awaken(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and inst.has_subtype("forest"):
			inst.cur_types |= Mtg.CardType.CREATURE
			game.continuous.lock_in(source, KEY, inst)


## Layer 7b: the Forests [method _awaken] animated are 1/1.
static func _size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if game.continuous.locked_in(source, KEY, inst):
			inst.cur_power = 1
			inst.cur_toughness = 1
