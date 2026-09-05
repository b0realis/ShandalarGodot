extends CardScript
## Wall of Shadows — {1}{B}{B} — Creature — Wall — 0/1 — (leg, common)
## Oracle: Defender (This creature can't attack.)
##         Prevent all damage that would be dealt to this creature by
##         creatures it's blocking.
##         This creature can't be the target of spells that can target
##         only Walls or of abilities that can target only Walls.
##
## Implementation: Wall of Vapor's source-filtered immunity in black, one
## mana cheaper, plus the third line: specs that can only ever name a Wall
## declare themselves with TargetSpec.only_walls() (the Glyph cycle, Animate
## Wall, Ali Baba), and this static raises the flag TargetSpec checks.


func build() -> CardData:
	return CardData.new("Wall of Shadows", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all damage that would be dealt to Wall of Shadows by creatures "
			+ "it's blocking, and it can't be the target of Wall-only spells or "
			+ "abilities.")) \
		.oracle("Defender (This creature can't attack.)\nPrevent all damage that "
			+ "would be dealt to this creature by creatures it's blocking.\nThis "
			+ "creature can't be the target of spells that can target only Walls or "
			+ "of abilities that can target only Walls.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_immune_to_wall_only = true
	source.cur_damage_immunity.append({
		"desc": "creatures it's blocking",
		"filter": _is_blocked_by.bind(source.id)})


static func _is_blocked_by(game: MtgGame, damager: CardInstance,
		wall_id: int) -> bool:
	return game.combat.is_blocking(wall_id, damager.id)
