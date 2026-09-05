extends CardScript
## Elder Land Wurm — {4}{W}{W}{W} — Creature — Dragon Wurm — 5/5 — (4ed, rare)
## Oracle: Defender, trample
##         When this creature blocks, it loses defender.
##
## Implementation: a BLOCKED trigger (self as blocker) that PERMANENTLY
## strips DEFENDER via MtgGame.remove_keyword_permanently — once it has
## tasted battle it may attack for the rest of its battlefield life.


func build() -> CardData:
	return CardData.new("Elder Land Wurm", "{4}{W}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["dragon", "wurm"]) \
		.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.TRAMPLE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _awaken,
			"When this creature blocks, it loses defender.",
			_self_blocks)) \
		.oracle("Defender, trample\nWhen this creature blocks, it loses defender.")


static func _self_blocks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["blocker"] == source


static func _awaken(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.remove_keyword_permanently(source, Mtg.Keyword.DEFENDER)
	game.log_line("%s loses defender" % source.data.card_name)
