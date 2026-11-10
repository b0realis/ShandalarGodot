extends CardScript
## Living Plane — {2}{G}{G} — World Enchantment — (leg, rare)
## Oracle: All lands are 1/1 creatures that are still lands.
##
## Implementation: one effect, keyed "living_plane"
## ([method StaticAbility.part_of]), in two layers: every land becomes a
## creature that is still a land in layer 4 — so the animated lands keep
## their mana abilities and gain summoning sickness like any other
## permanent, and a land played this turn can't attack — and every one of
## them has base power and toughness 1/1 in layer 7b, in timestamp order
## with the other 7b setters (CR 613.4b, 613.7). A land that is a creature
## already is a land too and is sized with the rest: a Mishra's Factory
## animated BEFORE Living Plane arrived is a 1/1, one animated after it a
## 2/2 — the later 7b effect wins (gap review 2026-11-10, r2-4; the card
## used to skip a land that was a creature already, and to write its 1/1 in
## layer 4, where an older animation's size overwrote it). A WORLD
## permanent (CR 704.5k).
##
## The famous combo half: with an Armageddon effect it is a one-sided
## board wipe, and it turns every Wrath into a land destruction spell.

const KEY := &"living_plane"


func build() -> CardData:
	return CardData.new("Living Plane", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(
			_apply, "All lands are creatures that are still lands.") \
			.changing_types().part_of(KEY)) \
		.static_ability(StaticAbility.new(
			_size, "The lands it animates have base power and toughness 1/1.") \
			.setting_base_pt().part_of(KEY)) \
		.oracle("All lands are 1/1 creatures that are still lands.")


## Layer 4: every land is a creature that is still a land.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land():
			inst.cur_types |= Mtg.CardType.CREATURE
			game.continuous.lock_in(source, KEY, inst)


## Layer 7b: every land [method _apply] reached is 1/1.
static func _size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if game.continuous.locked_in(source, KEY, inst):
			inst.cur_power = 1
			inst.cur_toughness = 1
