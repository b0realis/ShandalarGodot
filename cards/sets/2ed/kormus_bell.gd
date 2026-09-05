extends CardScript
## Kormus Bell — {4} — Artifact — (2ed, rare)
## Oracle: All Swamps are 1/1 black creatures that are still lands.
##
## Implementation: a MASS-ANIMATION static — every battlefield Swamp (by
## live subtype, so duals count) gains the CREATURE type with base P/T set
## to 1/1, keeping its land type and mana ability. Runs in the statics
## pass, so Bad Moon (a later timestamp usually) and counters still
## modify the 1/1 base. Freshly played swamps carry summoning sickness
## like every entering permanent (CR 302.6), and a Bolt kills them. The
## animated Swamps really are BLACK: the static writes cur_colors, so
## Terror refuses them and Bad Moon pumps them.


func build() -> CardData:
	return CardData.new("Kormus Bell", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_ring, "All Swamps are 1/1 black creatures that are still lands.") \
			.changing_types()) \
		.oracle("All Swamps are 1/1 black creatures that are still lands.")


static func _ring(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and inst.has_subtype("swamp"):
			inst.cur_types |= Mtg.CardType.CREATURE
			inst.cur_power = 1
			inst.cur_toughness = 1
			inst.cur_colors = Mtg.ManaColor.B
