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

	## Named after the card that looks — Clairvoyance borrows this effect
	## (campaign 2026-10-12, b4-6). A look at the looker's own hand keeps
	## the names out of the public line: the other seat never saw them.
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var looker := source.data.card_name if source != null else "Glasses of Urza"
		var names := PackedStringArray()
		for inst in game.players[target.player_id].hand:
			names.append(inst.data.card_name)
		game.reveal_information(controller, "%s — hand" % looker, Array(names))
		var whose := game.players[target.player_id].player_name
		var line := "%s reveals %s's hand: %s" % [looker, whose,
			", ".join(names) if names.size() > 0 else "(empty)"]
		if target.player_id == controller and names.size() > 0:
			game.log_line(line, null, "", controller, "%s looks at %s's hand" % [looker, whose])
		else:
			game.log_line(line)

	func describe() -> String:
		return "look at target player's hand"
