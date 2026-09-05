extends CardScript
## Lurker — {2}{G} — Creature — Beast — 2/3 — (drk, rare)
## Oracle: This creature can't be the target of spells unless it attacked
##         or blocked this turn.
##
## Implementation: a self-referential static raising the instance's
## "can't be the target of spells" flag while the Lurker has neither
## attacked nor blocked this turn. ABILITIES still target it (a Prodigal
## Sorcerer can still shoot it) — exactly what the printed wording says.


func build() -> CardData:
	return CardData.new("Lurker", "{2}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 3) \
		.with_subtypes(["beast"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Lurker can't be the target of spells unless it attacked or blocked this turn.")) \
		.oracle("This creature can't be the target of spells unless it attacked or "
			+ "blocked this turn.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	if not source.attacked_this_turn and not source.blocked_this_turn:
		source.cur_cant_be_spell_target = true
