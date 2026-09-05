extends CardScript
## Crevasse — {2}{R} — Enchantment — (leg, uncommon)
## Oracle: Creatures with mountainwalk can be blocked as though they
##         didn't have mountainwalk.
##
## Implementation: a static that adds "mountain" to
## MtgGame.nullified_landwalk, which CombatState consults when checking
## landwalk. The creatures KEEP the ability (a Goblin King's grant is
## still visible in cur_landwalk) — only the blocking rule changes, which
## is exactly what "as though" means.


func build() -> CardData:
	return CardData.new("Crevasse", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with mountainwalk can be blocked as though they didn't have "
			+ "mountainwalk.")) \
		.oracle("Creatures with mountainwalk can be blocked as though they didn't "
			+ "have mountainwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["mountain"] = true
