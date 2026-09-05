extends CardScript
## Invoke Prejudice — {U}{U}{U}{U} — Enchantment — (leg, rare)
## Oracle: Whenever an opponent casts a creature spell that doesn't share a
##         colour with a creature you control, counter that spell unless
##         that player pays {X}, where X is its mana value.
##
## Implementation: Nether Void's shape, narrowed to enemy CREATURE spells
## and gated on colour. The trigger goes on the stack above the spell, so
## the toll resolves while the spell is still there to be countered.
##
## The colour test reads LIVE colours on both sides (CONTRIBUTING.md rule 5): a
## Thoughtlaced blue Grizzly Bears on your board really does shelter a blue
## creature spell, and a Deathlaced spell really is black. A COLOURLESS
## creature spell shares a colour with nothing, so an artifact creature is
## always taxed — which is the printed card, not an oversight.
##
## X is the spell's mana value with the X it was cast for (CR 202.3b), so a
## Frankenstein's Monster cast for four costs four more to keep.


func build() -> CardData:
	return CardData.new("Invoke Prejudice", "{U}{U}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _toll,
			"Whenever an opponent casts a creature spell that doesn't share a color with a creature you control, counter that spell unless that player pays {X}, where X is its mana value.",
			_prejudiced_against)) \
		.oracle("Whenever an opponent casts a creature spell that doesn't share a color with "
			+ "a creature you control, counter that spell unless that player pays {X}, where "
			+ "X is its mana value.")


static func _prejudiced_against(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if int(event.data["controller"]) == source.controller_id:
		return false
	var spell: CardInstance = event.data["instance"]
	if spell == null or not spell.is_type(Mtg.CardType.CREATURE):
		return false
	for inst in game.players[source.controller_id].battlefield:
		if inst.is_creature() and (inst.cur_colors & spell.cur_colors) != 0:
			return false
	return true


static func _mana_value_of(spell: CardInstance) -> int:
	var mv := spell.data.cost.mana_value()
	if spell.data.cost.has_x:
		mv += int(spell.memory.get("x_value", 0)) * spell.data.cost.x_count
	return mv


static func _toll(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var spell: CardInstance = event.data["instance"]
	if spell == null or spell.zone != Mtg.Zone.STACK:
		return
	var caster := int(event.data["controller"])
	var cost := ManaCost.parse("{%d}" % _mana_value_of(spell))
	if game.can_afford_cost(caster, cost) \
			and game.agents[caster].choose_yes_no(game, caster,
				"Pay {%d} or %s is countered?" % [
					_mana_value_of(spell), spell.data.card_name], true) \
			and game.try_pay(caster, cost):
		return
	game.counter_spell(spell)
