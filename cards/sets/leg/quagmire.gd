extends CardScript
## Quagmire — {2}{B} — Enchantment — (leg, uncommon)
## Oracle: Creatures with swampwalk can be blocked as though they
##         didn't have swampwalk.
##
## Implementation: a static that adds "swamp" to
## MtgGame.nullified_landwalk, which CombatState consults when checking
## landwalk. The creatures KEEP the ability (a a Bog Wraith.s printed walk is
## still visible in cur_landwalk) — only the blocking rule changes, which
## is exactly what "as though" means.


func build() -> CardData:
	return CardData.new("Quagmire", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with swampwalk can be blocked as though they didn't have "
			+ "swampwalk.")) \
		.oracle("Creatures with swampwalk can be blocked as though they didn't "
			+ "have swampwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["swamp"] = true
