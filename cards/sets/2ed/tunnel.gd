extends CardScript
## Tunnel — {R} — Instant — (2ed, uncommon)
## Oracle: Destroy target Wall. It can't be regenerated.
##
## Implementation: filtered DestroyEffect with the no-regeneration rider —
## one red mana to delete any Wall (even a shielded Wall of Brambles),
## exactly the anti-Wall tech red was printed with.


func build() -> CardData:
	# An ability/spell that can target ONLY Walls — which Wall of Shadows
	# ("can't be the target of spells that can target only Walls or of
	# abilities that can target only Walls") reads off TargetSpec.only_walls.
	var spec := TargetSpec.creature("target Wall", _is_wall).only_walls()
	return CardData.new("Tunnel", "{R}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(spec, false)) \
		.oracle("Destroy target Wall. It can't be regenerated.")


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")
