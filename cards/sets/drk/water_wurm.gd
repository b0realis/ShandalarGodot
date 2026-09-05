extends CardScript
## Water Wurm — {U} — Creature — Wurm — 1/1 — (drk, common)
## Oracle: This creature gets +0/+1 as long as an opponent controls an Island.
##
## Implementation: a self-referential conditional static, re-evaluated on
## every recalculation — so the Wurm shrinks the moment their last Island
## is destroyed. Counts the LAND SUBTYPE (Tropical Island counts), not the
## card name.


func build() -> CardData:
	return CardData.new("Water Wurm", "{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["wurm"]) \
		.static_ability(StaticAbility.new(
			_apply, "Water Wurm gets +0/+1 as long as an opponent controls an Island.")) \
		.oracle("This creature gets +0/+1 as long as an opponent controls an Island.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id and inst.is_land() \
				and inst.has_subtype("island"):
			source.cur_toughness += 1
			return
