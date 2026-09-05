extends CardScript
## Elven Riders — {3}{G}{G} — Creature — Elf — 3/3 — (4ed, uncommon)
## Oracle: This creature can't be blocked except by Walls and/or creatures
##         with flying.
##
## Implementation: a SELF-static appending a block restriction (walls OR
## flyers) to its own cur_block_restrictions — the printed version of
## Invisibility's mechanism.


func build() -> CardData:
	return CardData.new("Elven Riders", "{3}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["elf"]) \
		.static_ability(StaticAbility.new(
			_restrict, "Can't be blocked except by Walls and/or creatures with flying.")) \
		.oracle("This creature can't be blocked except by Walls and/or creatures with flying.")


static func _wall_or_flyer(blocker: CardInstance) -> bool:
	return blocker.has_subtype("wall") or blocker.has_keyword(Mtg.Keyword.FLYING)


static func _restrict(_game: MtgGame, source: CardInstance) -> void:
	source.cur_block_restrictions.append(
		{"desc": "Walls and/or creatures with flying", "filter": _wall_or_flyer})
