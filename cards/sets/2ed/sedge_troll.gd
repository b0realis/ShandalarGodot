extends CardScript
## Sedge Troll — {2}{R} — Creature — Troll — 2/2 — (2ed, rare)
## Oracle: This creature gets +1/+1 as long as you control a Swamp.
##         {B}: Regenerate this creature.
##
## Implementation: a conditional SELF-static (+1/+1 while its controller
## has a Swamp — live subtype check, so Bayou and Badlands count) plus the
## standard {B} regeneration ability. The classic Badlands two-color
## payoff card. mage-go: BoostSelf(1,1, WhileControlling(Swamp)).


func build() -> CardData:
	return CardData.new("Sedge Troll", "{2}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["troll"]) \
		.static_ability(StaticAbility.new(
			_swamp_boost, "Gets +1/+1 as long as you control a Swamp.")) \
		.activated(ActivatedAbility.new(
			"{B}", false,
			[RegenerateEffect.new()],
			"{B}: Regenerate this creature.")) \
		.oracle("This creature gets +1/+1 as long as you control a Swamp.\n{B}: Regenerate this creature.")


static func _swamp_boost(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_land() and inst.has_subtype("swamp"):
			source.cur_power += 1
			source.cur_toughness += 1
			return
