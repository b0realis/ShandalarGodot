extends CardScript
## Spell Blast — {X}{U} — Instant — (2ed, common)
## Oracle: Counter target spell with mana value X.
##
## Implementation: "with mana value X" is part of the TARGETING
## restriction (CR 115.4) — a Spell Blast for 2 may not be aimed at a
## Lightning Bolt at all. The filter is source-aware and reads
## MtgGame.casting_x — the X a planner is TRYING ON while it sizes the
## Blast, and the announced one once the spell is on the stack, which is
## still there when it resolves (so a Blast whose target's mana value
## changed would fizzle rather than counter).
## mage-go counters whenever X >= the mana value; oracle (and this) demand
## equality.


func build() -> CardData:
	return CardData.new("Spell Blast", "{X}{U}", Mtg.CardType.INSTANT) \
		.spell(BlastEffect.new()) \
		.oracle("Counter target spell with mana value X.")


class BlastEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell("target spell with mana value X")
		target_spec.with_source_filter(BlastEffect._mana_value_is_x)

	## CR 202.3b — while a spell is ON THE STACK, X in its mana cost is the
	## value chosen for it, and ManaCost.mana_value() deliberately counts an
	## unresolved X as 0. Invoke Prejudice and Mana Drain read it the same
	## way; without this a Spell Blast for 4 could never name a Fireball cast
	## for X=3, and a Spell Blast for 1 could counter any X spell at all.
	static func _mana_value_is_x(game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		return BlastEffect._mana_value_of(inst) == game.casting_x(source)

	static func _mana_value_of(spell: CardInstance) -> int:
		var mv := spell.data.cost.mana_value()
		if spell.data.cost.has_x:
			mv += int(spell.memory.get("x_value", 0)) * spell.data.cost.x_count
		return mv

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK:
			return
		game.counter_spell(spell)

	func describe() -> String:
		return "counters target spell with mana value X"
