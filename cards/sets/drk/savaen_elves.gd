extends CardScript
## Savaen Elves — {G} — Creature — Elf — 1/1 — (drk, common)
## Oracle: {G}{G}, {T}: Destroy target Aura attached to a land.
##
## Implementation: Miracle Worker's shape aimed at land auras instead —
## any land, either player's, so it answers Psychic Venom, Evil Presence
## and Kudzu. The filter reads the host's LIVE type, so an animated land
## still counts.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target Aura attached to a land")
	spec.with_game_filter(_aura_on_a_land)
	return CardData.new("Savaen Elves", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["elf"]) \
		.activated(ActivatedAbility.new(
			"{G}{G}", true, [DestroyEffect.new(spec)],
			"{G}{G}, {T}: Destroy target Aura attached to a land.")) \
		.oracle("{G}{G}, {T}: Destroy target Aura attached to a land.")


static func _aura_on_a_land(game: MtgGame, inst: CardInstance) -> bool:
	if not inst.data.is_aura() or inst.attached_to == -1:
		return false
	var host := game.find_instance(inst.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD and host.is_land()
