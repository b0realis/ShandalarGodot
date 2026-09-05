extends CardScript
## Visions — {W} — Sorcery — (4ed, uncommon)
## Oracle: Look at the top five cards of target player's library. You may
##         then have that player shuffle that library.
##
## Implementation: pure information plus an optional shuffle — the effect
## logs the five cards (so a UI can show them) and asks the caster's
## DecisionAgent whether to shuffle. Nothing moves zones either way.


func build() -> CardData:
	return CardData.new("Visions", "{W}", Mtg.CardType.SORCERY) \
		.spell(VisionsEffect.new()) \
		.oracle("Look at the top five cards of target player's library. You may then "
			+ "have that player shuffle that library.")


class VisionsEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var library := game.players[target.player_id].library
		var names := PackedStringArray()
		for i in range(library.size() - 1, maxi(library.size() - 6, -1), -1):
			names.append(library[i].data.card_name)
		game.log_line("Visions reveals the top of %s's library: %s" % [
			game.players[target.player_id].player_name,
			", ".join(names) if names.size() > 0 else "(empty)"])
		if game.agents[controller].choose_yes_no(game, controller,
				"Have that player shuffle?", false):
			game._shuffle(library)
			game.log_line("%s shuffles" % game.players[target.player_id].player_name)

	func describe() -> String:
		return "look at the top five cards of target player's library"
