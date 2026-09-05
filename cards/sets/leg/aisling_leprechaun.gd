extends CardScript
## Aisling Leprechaun — {G} — Creature — Faerie — 1/1 — (leg, common)
## Oracle: Whenever this creature blocks or becomes blocked by a creature,
##         that creature becomes green. (This effect lasts indefinitely.)
##
## Implementation: the BLOCKED event carries both halves of the pair, so
## the trigger paints whichever of them isn't the Leprechaun. The change is
## INDEFINITE — colour_override on the instance — which is what makes the
## Leprechaun a real answer to protection-from-green and a real enabler for
## the green sweepers (Tsunami-style effects read cur_colors now).


func build() -> CardData:
	return CardData.new("Aisling Leprechaun", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["faerie"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _paint,
			"Whenever this creature blocks or becomes blocked by a creature, that creature becomes green.",
			_involves_self)) \
		.oracle("Whenever this creature blocks or becomes blocked by a creature, that creature becomes green. (This effect lasts indefinitely.)")


static func _other(source: CardInstance, event: GameEvent) -> CardInstance:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	if attacker == source:
		return blocker
	if blocker == source:
		return attacker
	return null


static func _involves_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return _other(source, event) != null


static func _paint(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var other := _other(source, event)
	if other != null and other.zone == Mtg.Zone.BATTLEFIELD:
		game.set_color(other, Mtg.ManaColor.G)
