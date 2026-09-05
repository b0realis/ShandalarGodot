extends CardScript
## Glasses of Urza — {1} — Artifact — (2ed, uncommon)
## Oracle: {T}: Look at target player's hand.
##
## Implementation: pure information — the effect logs the target's hand
## so a UI can show it, and changes nothing else. In a headless duel it
## is a no-op with a paper trail; against a human it is the reason
## Mind Twist decks of the era ran it.


func build() -> CardData:
	return CardData.new("Glasses of Urza", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [PeekEffect.new()],
			"{T}: Look at target player's hand.")) \
		.oracle("{T}: Look at target player's hand.")


class PeekEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var names := PackedStringArray()
		for inst in game.players[target.player_id].hand:
			names.append(inst.data.card_name)
		game.log_line("Glasses of Urza reveals %s's hand: %s" % [
			game.players[target.player_id].player_name,
			", ".join(names) if names.size() > 0 else "(empty)"])

	func describe() -> String:
		return "look at target player's hand"
