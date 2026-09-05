extends CardScript
## Mana Flare — {2}{R} — Enchantment (2ed, rare)
## Oracle: Whenever a player taps a land for mana, that player adds one
##         mana of any type that land produced.
##
## Implementation: the reference MANA TRIGGER — a TriggeredAbility marked
## as_mana_trigger(), so it resolves IMMEDIATELY off-stack (CR 605.1b)
## when TAPPED_FOR_MANA fires, and the bonus mana is usable mid-payment.
## Symmetric (both players benefit), as printed — the reason the red
## castle's standing Mana Flare terrifies (dos486: it supercharges every
## X-spell in the room, yours and theirs).
##
## "Any type that land produced": the event carries every type the tap
## made (`colors`). A dual land in this pool taps for ONE of its colours
## per activation, so the bonus is that colour and there is nothing to
## ask — Duel.hlp: "Whenever any player taps a land for mana, it produces
## one additional mana of the same type." An ability that makes two types
## at once puts the type to the tapping player (DecisionAgent.choose_option,
## `@MULTIMANA`'s "%s: What kind of mana?"), once per Mana Flare — Duel.hlp
## again: "If the ability that was used produces mana of more than one
## type, you can choose which type of mana is produced by Mana Flare. If
## there is more than one Mana Flare in play, you make a separate choice
## for each Mana Flare." The heuristic doubles the first type made.


func build() -> CardData:
	return CardData.new("Mana Flare", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.TAPPED_FOR_MANA,
			_bonus_mana,
			"Whenever a player taps a land for mana, that player adds one mana of any type that land produced.")
			.as_mana_trigger()) \
		.oracle("Whenever a player taps a land for mana, that player adds one mana of any type that land produced.")


static func _bonus_mana(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["controller"]
	var color: int = int(event.data["color"])
	var types: Array = event.data.get("colors", [color])
	if types.size() > 1:
		var labels: Array[String] = []
		for t in types:
			labels.append(Mtg.COLOR_NAMES[int(t)])
		var picked: int = game.agents[pid].choose_option(game, pid, labels,
			PlayerChoice.mana_color_prompt("Mana Flare"), maxi(types.find(color), 0))
		color = int(types[picked])
	game.players[pid].mana_pool.add(color, 1)
	game.log_line("Mana Flare adds a bonus %s" % Mtg.COLOR_NAMES[color])
