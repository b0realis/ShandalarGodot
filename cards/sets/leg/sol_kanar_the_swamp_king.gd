extends CardScript
## Sol'kanar the Swamp King — {2}{U}{B}{R} — Legendary Creature — Demon —
## 5/5 (leg, rare)
## Oracle: Swampwalk
##         Whenever a player casts a black spell, you gain 1 life.
##
## Implementation: swampwalk + a SPELL_CAST trigger keyed on spell COLOR
## (any caster — even the opponent's Terror feeds him). The 1997 legend
## rule is a state-based action (MtgGame.check_state_based_actions): while
## two Sol'kanars are on the battlefield the NEWEST one is buried, which is
## the era's "first in time, first in right" wording rather than the modern
## controller-chooses 704.5j.


func build() -> CardData:
	return CardData.new("Sol'kanar the Swamp King", "{2}{U}{B}{R}",
			Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["demon"]) \
		.with_landwalk(["swamp"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _relish,
			"Whenever a player casts a black spell, you gain 1 life.",
			_is_black_spell)) \
		.oracle("Swampwalk\nWhenever a player casts a black spell, you gain 1 life.")


static func _is_black_spell(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	return (event.data["instance"].cur_colors & Mtg.ManaColor.B) != 0


static func _relish(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.adjust_life(source.controller_id, 1)
