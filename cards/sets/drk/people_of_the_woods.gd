extends CardScript
## People of the Woods — {G}{G} — Creature — Human — 1/* — (drk, uncommon)
## Oracle: People of the Woods's toughness is equal to the number of
##         Forests you control.
##
## Implementation: a dynamic-toughness static (Nightmare's pattern) that
## SETS the toughness each recalculation rather than adding to it. With
## no Forests it is a 1/0 and dies to state-based actions immediately —
## printed behavior, and the reason it only ever appears in mono-green.


func build() -> CardData:
	return CardData.new("People of the Woods", "{G}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 0) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"People of the Woods's toughness is equal to the number of Forests you control.").setting_base_pt()) \
		.oracle("People of the Woods's toughness is equal to the number of Forests you control.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var forests := 0
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_land() \
				and inst.has_subtype("forest"):
			forests += 1
	source.cur_toughness = forests
