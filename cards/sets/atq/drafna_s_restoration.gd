extends CardScript
## Drafna's Restoration — {U} — Sorcery — (atq, common)
## Oracle: Put any number of target artifact cards from target player's
##         graveyard on top of their library in any order.
##
## Implementation: TWO target slots, in the order the original asks them
## (`@DRAFNAS_RESTORATION`, Program/promptsX1.txt:138 — "Select target
## player." / "Select an artifact." / "Done"): the player, then "any number
## of target artifact cards" as a 0..N group (EffectBase.one_or_more with a
## 0 minimum) whose spec is stated RELATIVE to the player slot — a
## TargetSpec.sibling_filter admits only cards in THAT player's graveyard,
## refusing any other with the original's `Illegal target (owner).` The
## cards go on top in the order chosen — the last card named ends up on
## top, which is the "in any order" clause — and a player may be named
## with no cards at all ("any number" includes none).


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.data.is_type(Mtg.CardType.ARTIFACT)


## "… from TARGET PLAYER's graveyard": [param earlier] holds the player
## slot's ref.
static func _in_that_players_graveyard(game: MtgGame, _source: CardInstance,
		candidate: TargetRef, earlier: Array) -> bool:
	var inst := game.find_instance(candidate.instance_id)
	return inst != null and inst.owner_id == earlier[0].player_id


func build() -> CardData:
	var cards := TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD,
		"target artifact card in that player's graveyard", _is_artifact) \
		.with_sibling_filter(_in_that_players_graveyard, TargetSpec.WHY["owner"])
	return CardData.new("Drafna's Restoration", "{U}", Mtg.CardType.SORCERY) \
		.spell(PlayerSlotEffect.new()) \
		.spell(RestoreEffect.new(cards)) \
		.oracle("Put any number of target artifact cards from target player's graveyard on top of their library in any order.")


## "Target player" — the slot the cards are read against. Whose library
## the cards go on top of is settled by the cards themselves (their
## owner's), so the slot has nothing to do on its own.
class PlayerSlotEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
		helpful()   # the AI restores its OWN artifacts

	func resolve(_game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		pass

	func describe() -> String:
		return "the player whose graveyard is restored"


class RestoreEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec
		one_or_more()
		target_min = 0   # "any number" includes none
		helpful()

	func resolve_multi(game: MtgGame, _source: CardInstance, _controller: int,
			targets: Array, _x_value: int = 0) -> void:
		for ref in targets:
			var inst := game.find_instance(ref.instance_id)
			if inst != null:
				game.return_from_graveyard_to_library_top(inst)

	func describe() -> String:
		return "puts any number of target artifact cards from that player's graveyard on top of their library"
