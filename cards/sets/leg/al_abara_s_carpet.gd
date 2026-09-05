extends CardScript
## Al-abara's Carpet — {5} — Artifact — (leg, rare)
## Oracle: {5}, {T}: Prevent all damage that would be dealt to you this
##         turn by attacking creatures without flying.
##
## Implementation: a predicate-keyed damage shield on its controller — the
## same list Circle of Protection: Artifacts uses — whose filter asks the
## live combat state whether the source is a non-flying attacker.
##
## Unlike a Circle this is a DURATION effect, not "the next time": it must
## cover every ground attacker for the rest of the turn, including
## attackers declared AFTER it was activated (unfurling the Carpet in your
## opponent's main phase is the whole point of holding it up). The shield
## list is one-shot by default — MtgGame.deal_damage consumes the entry it
## matched — so the entry carries the list's own `all_turn` flag, exactly
## as Scarecrow's does, and stays until the list is cleared at cleanup,
## which is the printed "this turn".
##
## The filter needs the combat state, so it is handed the game through a
## WeakRef and NOT bound directly: the entry lives inside the game's own
## player object, and a strong reference back would be a cycle that leaks
## the whole game whenever a duel ends with the Carpet unfurled (the
## second review of 2026-09-02 found this card's two tests leaking one).


func build() -> CardData:
	return CardData.new("Al-abara's Carpet", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{5}", true, [CarpetEffect.new()],
			"{5}, {T}: Prevent all damage that would be dealt to you this turn by attacking creatures without flying.")) \
		.oracle("{5}, {T}: Prevent all damage that would be dealt to you this turn by attacking creatures without flying.")


class CarpetEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.players[controller].prevention_shield_filters.append({
			"desc": "attacking creatures without flying",
			"filter": CarpetEffect._is_ground_attacker.bind(weakref(game)),
			"all_turn": true,
		})
		game.log_line("Al-abara's Carpet unfurls")

	## Is [param source] attacking right now, and on the ground?
	static func _is_ground_attacker(source: CardInstance, game_ref: WeakRef) -> bool:
		var game: MtgGame = game_ref.get_ref()
		if game == null or not game.combat.attackers.has(source.id):
			return false
		return not source.has_keyword(Mtg.Keyword.FLYING)

	func describe() -> String:
		return "prevents damage from attacking creatures without flying this turn"
