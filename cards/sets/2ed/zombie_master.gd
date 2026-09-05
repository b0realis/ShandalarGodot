extends CardScript
## Zombie Master — {1}{B}{B} — Creature — Zombie — 2/3 — (2ed, rare)
## Oracle: Other Zombie creatures have swampwalk.
##         Other Zombies have "{B}: Regenerate this permanent."
##
## Implementation: a tribal lord that grants BOTH a landwalk (appended to
## the other Zombies' live landwalk list) and an ACTIVATED ABILITY
## (appended to their live ability list — the engine activates from
## cur_activated_abilities, so a granted ability is a real one). "Other"
## is enforced, so the Master neither walks nor regenerates itself.


func build() -> CardData:
	return CardData.new("Zombie Master", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["zombie"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Other Zombie creatures have swampwalk and \"{B}: Regenerate this permanent.\"")) \
		.oracle("Other Zombie creatures have swampwalk. (They can't be blocked as long "
			+ "as defending player controls a Swamp.)\nOther Zombies have \"{B}: "
			+ "Regenerate this permanent.\"")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst == source or not inst.is_creature() or not inst.has_subtype("zombie"):
			continue
		if not inst.cur_landwalk.has("swamp"):
			inst.cur_landwalk.append("swamp")
		inst.cur_activated_abilities.append(ActivatedAbility.new(
			"{B}", false, [RegenerateEffect.new()],
			"{B}: Regenerate this permanent."))
