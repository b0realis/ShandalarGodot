extends CardScript
## Undertow — {2}{U} — Enchantment — (leg, uncommon)
## Oracle: Creatures with islandwalk can be blocked as though they
##         didn't have islandwalk.
##
## Implementation: a static that adds "island" to
## MtgGame.nullified_landwalk, which CombatState consults when checking
## landwalk. The creatures KEEP the ability (a a Fishliver Oil grant is
## still visible in cur_landwalk) — only the blocking rule changes, which
## is exactly what "as though" means.


func build() -> CardData:
	return CardData.new("Undertow", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with islandwalk can be blocked as though they didn't have "
			+ "islandwalk.")) \
		.oracle("Creatures with islandwalk can be blocked as though they didn't "
			+ "have islandwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["island"] = true
