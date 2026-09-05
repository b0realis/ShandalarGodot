extends CardScript
## Scarecrow — {5} — Artifact Creature — Scarecrow — 2/2 — (drk, uncommon)
## Oracle: {6}, {T}: Prevent all damage that would be dealt to you this turn
##         by creatures with flying.
##
## Implementation: a predicate damage shield on the seat
## (MtgPlayer.prevention_shield_filters, the same list Circle of Protection:
## Artifacts uses) marked `all_turn` — the Circles' shields are one-shot,
## and this one is not: "prevent ALL damage ... this turn" survives every
## packet until cleanup clears it.
##
## The predicate reads the LIVE keyword (CONTRIBUTING.md rule 5), so a flier that
## loses flying before combat damage gets through, and a ground creature
## granted flying by a Jump does not.
##
## Eleven mana for one turn of anti-air is why nobody played it; the card is
## here because the pool is the pool.


func build() -> CardData:
	return CardData.new("Scarecrow", "{5}", Mtg.CardType.ARTIFACT
			| Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["scarecrow"]) \
		.activated(ActivatedAbility.new("{6}", true, [ShieldEffect.new()],
			"{6}, {T}: Prevent all damage that would be dealt to you this turn by creatures with flying.")) \
		.oracle("{6}, {T}: Prevent all damage that would be dealt to you this turn "
			+ "by creatures with flying.")


class ShieldEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # legal in the 1997 damage window (§6.8)

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].prevention_shield_filters.append({
			"desc": "creatures with flying",
			"filter": ShieldEffect._flying_creature,
			"all_turn": true,
		})
		game.log_line("%s raises the Scarecrow against fliers"
			% game.players[controller].player_name)

	static func _flying_creature(source: CardInstance) -> bool:
		return source.is_creature() and source.has_keyword(Mtg.Keyword.FLYING)

	func describe() -> String:
		return "prevents all damage from fliers to you this turn"
