extends CardScript
## Knowledge Vault — {4} — Artifact — (leg, rare)
## Oracle: {2}, {T}: Exile the top card of your library face down.
##         {0}: Sacrifice this artifact. If you do, discard your hand, then
##         put all cards exiled with this artifact into their owner's hand.
##         When this artifact leaves the battlefield, put all cards exiled
##         with it into their owner's graveyard.
##
## Implementation: the Vault remembers the ids of everything it exiled in
## its own card-local memory, and its leave-trigger reads the memory
## SNAPSHOT the engine hands to departing permanents — so the "cash it in"
## ability (which sacrifices the Vault) and a Disenchant both find the
## hoard. Cashing in wins the race because the ability empties the hoard
## into your hand before the leave-trigger resolves — but the whole payout
## is gated on the sacrifice actually happening ("if you do"), so a Vault
## destroyed while its {0} ability is on the stack costs you neither your
## hand nor a second chance.


func build() -> CardData:
	return CardData.new("Knowledge Vault", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{2}", true, [StoreCardEffect.new()],
			"{2}, {T}: Exile the top card of your library face down.")) \
		.activated(ActivatedAbility.new("", false, [CashInEffect.new()],
			"{0}: Sacrifice this artifact. If you do, discard your hand, then put all cards exiled with it into their owner's hand.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _bury_the_hoard,
			"When this artifact leaves the battlefield, put all cards exiled with it into their owner's graveyard.",
			_is_self_leaving)) \
		.oracle("{2}, {T}: Exile the top card of your library face down.\n{0}: Sacrifice this artifact. If you do, discard your hand, then put all cards exiled with this artifact into their owner's hand.\nWhen this artifact leaves the battlefield, put all cards exiled with it into their owner's graveyard.")


static func _is_self_leaving(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var parting: Dictionary = event.data.get("memory", {})
	return event.data.get("instance") == source and not Array(parting.get("hoard", [])).is_empty()


static func _bury_the_hoard(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var parting: Dictionary = event.data.get("memory", {})
	for card_id in Array(parting.get("hoard", [])):
		var card := game.find_instance(int(card_id))
		if card != null and card.zone == Mtg.Zone.EXILE:
			game.return_from_exile_to_graveyard(card)


class StoreCardEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		if game.players[controller].library.is_empty():
			return
		var card := game.exile_top_of_library(controller)
		if card == null:
			return
		var hoard: Array = source.memory.get("hoard", [])
		hoard.append(card.id)
		source.memory["hoard"] = hoard

	func describe() -> String:
		return "exiles the top card of your library face down"


class CashInEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# "Sacrifice this artifact. IF YOU DO, discard your hand, then ..."
		# A Vault that was already destroyed in response cannot be
		# sacrificed (CR 701.17b: you can only sacrifice a permanent you
		# control), so the whole payload is skipped — your hand survives.
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var hoard: Array = Array(source.memory.get("hoard", []))
		source.memory.erase("hoard")   # the leave-trigger must find nothing
		game.sacrifice_permanent(source)
		game.discard_hand(controller)
		for card_id in hoard:
			var card := game.find_instance(int(card_id))
			if card != null and card.zone == Mtg.Zone.EXILE:
				game.return_from_exile_to_hand(card)

	func describe() -> String:
		return "sacrifices the Vault to trade your hand for everything it holds"
