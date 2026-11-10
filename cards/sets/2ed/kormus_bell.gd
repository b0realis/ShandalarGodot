extends CardScript
## Kormus Bell — {4} — Artifact — (2ed, rare)
## Oracle: All Swamps are 1/1 black creatures that are still lands.
##
## Implementation: a MASS-ANIMATION — one effect in three layers (CR 613.1,
## 613.6), printed as three statics that share the key "bell"
## ([method StaticAbility.part_of]):
##
## - LAYER 4: every battlefield Swamp (by live subtype, so duals count)
##   gains the CREATURE type, keeping its land type and mana ability, and is
##   named as one of the effect's objects ([method ContinuousEffects.lock_in]).
## - LAYER 5: those Swamps are BLACK ([method StaticAbility.changing_colors]),
##   in timestamp order with the other colour effects (CR 613.7): Terror
##   refuses them and Bad Moon pumps them, and a Chaoslace cast on one after
##   the Bell entered makes it red (gap review 2026-11-10, r2-3).
## - LAYER 7b: base power and toughness 1/1 ([method
##   StaticAbility.setting_base_pt]), in timestamp order with the other 7b
##   setters — a Swamp a Verdant Touch made a 2/2 before the Bell arrived is
##   a 1/1, one animated after it a 2/2 (CR 613.4b, 613.7; r2-4). Counters
##   and Bad Moon still add on top.
##
## The key keeps the colour and the size going after the Bell loses its
## abilities: Titania's Song makes it a 4/4 artifact creature with no
## abilities in layer 6, but the Bell's effect started in layer 4, so the
## Swamps stay 1/1 black creatures (the owner's ruling of 2026-11-10, CR
## 613.6). Freshly played Swamps carry summoning sickness like every
## entering permanent (CR 302.6), and a Bolt kills them.

const KEY := &"bell"


func build() -> CardData:
	return CardData.new("Kormus Bell", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_ring, "All Swamps are creatures that are still lands.") \
			.changing_types().part_of(KEY)) \
		.static_ability(StaticAbility.new(
			_paint, "The Swamps it animates are black.") \
			.changing_colors().part_of(KEY)) \
		.static_ability(StaticAbility.new(
			_size, "The Swamps it animates have base power and toughness 1/1.") \
			.setting_base_pt().part_of(KEY)) \
		.oracle("All Swamps are 1/1 black creatures that are still lands.")


## Layer 4: every Swamp is a creature that is still a land.
static func _ring(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and inst.has_subtype("swamp"):
			inst.cur_types |= Mtg.CardType.CREATURE
			game.continuous.lock_in(source, KEY, inst)


## Layer 5: the Swamps [method _ring] animated are black.
static func _paint(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if game.continuous.locked_in(source, KEY, inst):
			inst.cur_colors = Mtg.ManaColor.B


## Layer 7b: and 1/1.
static func _size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if game.continuous.locked_in(source, KEY, inst):
			inst.cur_power = 1
			inst.cur_toughness = 1
