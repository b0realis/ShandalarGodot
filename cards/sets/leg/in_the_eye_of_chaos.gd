extends CardScript
## In the Eye of Chaos — {2}{U} — World Enchantment — (leg, rare)
## Oracle: Whenever a player casts an instant spell, counter it unless
##         that player pays {X}, where X is its mana value.
##
## Implementation: Nether Void's shape, narrowed to instants and with the
## toll scaled to the spell's mana value (an {X} spell's own X is not
## counted here — the engine reads the printed mana value, which is what
## the card's controller committed to on cast). A WORLD permanent.


func build() -> CardData:
	return CardData.new("In the Eye of Chaos", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _toll,
			"Whenever a player casts an instant spell, counter it unless that player "
			+ "pays {X}, where X is its mana value.",
			_is_instant)) \
		.oracle("Whenever a player casts an instant spell, counter it unless that "
			+ "player pays {X}, where X is its mana value.")


static func _is_instant(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	var spell: CardInstance = event.data["instance"]
	return spell != null and spell.data.is_type(Mtg.CardType.INSTANT)


## CR 202.3b — a spell on the stack has the X it was cast for, and
## ManaCost.mana_value() counts an unresolved X as 0. Invoke Prejudice, in
## this same set, reads it exactly this way.
static func _mana_value_of(spell: CardInstance) -> int:
	var mv := spell.data.cost.mana_value()
	if spell.data.cost.has_x:
		mv += int(spell.memory.get("x_value", 0)) * spell.data.cost.x_count
	return mv


static func _toll(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var spell: CardInstance = event.data["instance"]
	if spell == null or spell.zone != Mtg.Zone.STACK:
		return
	var caster: int = event.data["controller"]
	var value := _mana_value_of(spell)
	var cost := ManaCost.parse("{%d}" % value)
	if game.can_afford_cost(caster, cost) \
			and game.agents[caster].choose_yes_no(game, caster,
				"Pay {%d} or %s is countered?" % [
					value, spell.data.card_name], true) \
			and game.try_pay(caster, cost):
		return
	game.counter_spell(spell)
