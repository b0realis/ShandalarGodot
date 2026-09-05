extends CardScript
## Great Wall — {2}{W} — Enchantment — (leg, uncommon)
## Oracle: Creatures with plainswalk can be blocked as though they
##         didn't have plainswalk.
##
## Implementation: a static that adds "plains" to
## MtgGame.nullified_landwalk, which CombatState consults when checking
## landwalk. The creatures KEEP the ability (a a granted walk is
## still visible in cur_landwalk) — only the blocking rule changes, which
## is exactly what "as though" means.


func build() -> CardData:
	return CardData.new("Great Wall", "{2}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with plainswalk can be blocked as though they didn't have "
			+ "plainswalk.")) \
		.oracle("Creatures with plainswalk can be blocked as though they didn't "
			+ "have plainswalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["plains"] = true
