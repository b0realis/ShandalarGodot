extends CardScript
## Necropolis — {5} — Artifact Creature — Wall — 0/1 — (drk, uncommon)
## Oracle: Defender (This creature can't attack.)
##         Exile a creature card from your graveyard: Put X +0/+1 counters
##         on this creature, where X is the exiled card's mana value.
##
## Implementation: the corpse is a COST, not a target — it is exiled as the
## ability is activated (ActivatedAbility.with_exile_from_graveyard,
## CR 601.2h), so two activations can never eat the same body and nothing
## can be removed from the graveyard in response. The engine leaves what the
## cost ate on THIS ACTIVATION's stack item (`StackItem.cost_paid`, key
## `_exiled_mana_value`), which is the X this ability wants — per
## activation, because the ability is free and two of them on the stack
## would otherwise read each other's corpse.
##
## +0/+1 counters are an ordinary counter kind: the continuous pipeline
## reads any "+A/+B"-named counter in layer 7d, so a Necropolis fed a Sengir
## Vampire is a 0/6 Wall with nothing card-specific in the engine.
##
## Free to activate, so a graveyard full of cheap creatures is worth as much
## as one expensive one — mana value 0 corpses (a Kobold, a token that never
## was a card) simply add nothing.


func build() -> CardData:
	return CardData.new("Necropolis", "{5}", Mtg.CardType.ARTIFACT
			| Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.activated(ActivatedAbility.new("", false, [FeedEffect.new()],
			"Exile a creature card from your graveyard: Put X +0/+1 counters on this creature, where X is the exiled card's mana value.") \
			.with_exile_from_graveyard("creature card", _is_creature_card)) \
		.oracle("Defender (This creature can't attack.)\nExile a creature card from "
			+ "your graveyard: Put X +0/+1 counters on this creature, where X is the "
			+ "exiled card's mana value.")


static func _is_creature_card(inst: CardInstance) -> bool:
	return inst.data.is_creature()


class FeedEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var x := int(game.cost_paid("_exiled_mana_value", 0))
		if x <= 0:
			return
		game.add_counters(source, "+0/+1", x)

	func describe() -> String:
		return "grows by the exiled creature's mana value"
