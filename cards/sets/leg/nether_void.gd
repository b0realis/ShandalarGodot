extends CardScript
## Nether Void — {3}{B} — World Enchantment — (leg, rare)
## Oracle: Whenever a player casts a spell, counter it unless that player
##         pays {3}.
##
## Implementation: a SPELL_CAST trigger. Triggers go on the stack ABOVE
## the spell that caused them, so the toll resolves first and the spell is
## still sitting there to be countered. Symmetric — the Void taxes its own
## controller too. A WORLD permanent (CR 704.5k).


func build() -> CardData:
	return CardData.new("Nether Void", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _toll,
			"Whenever a player casts a spell, counter it unless that player pays {3}.")) \
		.oracle("Whenever a player casts a spell, counter it unless that player pays {3}.")


static func _toll(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var spell: CardInstance = event.data["instance"]
	if spell == null or spell.zone != Mtg.Zone.STACK:
		return
	var caster: int = event.data["controller"]
	var cost := ManaCost.parse("{3}")
	if game.can_afford_cost(caster, cost) \
			and game.agents[caster].choose_yes_no(game, caster,
				"Pay {3} or %s is countered?" % spell.data.card_name, true) \
			and game.try_pay(caster, cost):
		return
	game.counter_spell(spell)
