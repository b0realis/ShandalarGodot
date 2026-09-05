extends CardScript
## Powerleech — {G}{G} — Enchantment — (atq, uncommon)
## Oracle: Whenever an artifact an opponent controls becomes tapped or an
##         opponent activates an artifact's ability without {T} in its
##         activation cost, you gain 1 life.
##
## Implementation: one trigger per printed clause. BECAME_TAPPED, gated on
## the tapped permanent being an artifact an opponent controls; and
## ABILITY_ACTIVATED, gated on the ACTIVATOR being an opponent and the
## source an artifact — note the second clause says "an artifact's ability",
## not "an artifact an opponent controls", so an opponent reaching for an
## ability of OUR artifact (Land's Edge's "any player may activate") feeds
## us too.
##
## The "without {T}" gate keeps a "{T}: ..." ability to ONE trigger, via
## the tap clause — the modern wording of the ruling the original shipped:
## *"Tapping an artifact as part of its activation cost will only cause
## Powerleech's ability to trigger once"* (Duel.hlp, Powerleech, Wizards of
## the Coast Rulings).
##
## mage-go deviates: it does not implement Powerleech at all. Duel.hlp's own
## card text deviates too — it reads *"Whenever TARGET opponent plays an
## artifact ability requiring an activation cost..."*, i.e. the 1997 card
## was aimed at one opponent and fired on ANY activation cost. Two-player
## duels make "target opponent" and "an opponent" the same player, and we
## follow the oracle on the cost clause.


func build() -> CardData:
	return CardData.new("Powerleech", "{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _drink,
			"Whenever an artifact an opponent controls becomes tapped, you gain 1 life.",
			_their_artifact)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ABILITY_ACTIVATED, _drink,
			"Whenever an opponent activates an artifact's ability without {T} in "
			+ "its activation cost, you gain 1 life.",
			_their_artifact_ability)) \
		.oracle("Whenever an artifact an opponent controls becomes tapped or an "
			+ "opponent activates an artifact's ability without {T} in its activation "
			+ "cost, you gain 1 life.")


static func _their_artifact(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.controller_id != source.controller_id \
		and inst.is_type(Mtg.CardType.ARTIFACT)


static func _their_artifact_ability(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if bool(event.data.get("taps", false)):
		return false   # the tap clause already caught this one
	if int(event.data.get("player", -1)) == source.controller_id:
		return false   # "an OPPONENT activates" — our own activations pay nothing
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.is_type(Mtg.CardType.ARTIFACT)


static func _drink(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.adjust_life(source.controller_id, 1)
