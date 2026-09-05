extends CardScript
## Living Plane — {2}{G}{G} — World Enchantment — (leg, rare)
## Oracle: All lands are 1/1 creatures that are still lands.
##
## Implementation: a global static that adds CREATURE to every land's LIVE
## type mask and sets its base P/T to 1/1 — the animated lands keep their
## mana abilities (they are "still lands") and gain summoning sickness
## like any other permanent, so a land played this turn can't attack.
## A land ALREADY animated by its own ability (Mishra's Factory) keeps
## that animation's P/T — the more specific effect wins, which is the same
## call the engine's simplified layer ordering makes everywhere
## (docs/ROADMAP.md). A WORLD permanent (CR 704.5k).
##
## The famous combo half: with an Armageddon effect it is a one-sided
## board wipe, and it turns every Wrath into a land destruction spell.


func build() -> CardData:
	return CardData.new("Living Plane", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(
			_apply, "All lands are 1/1 creatures that are still lands.") \
			.changing_types()) \
		.oracle("All lands are 1/1 creatures that are still lands.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_land():
			continue
		if inst.is_creature():
			continue   # already animated by something more specific
		inst.cur_types |= Mtg.CardType.CREATURE
		inst.cur_power = 1
		inst.cur_toughness = 1
