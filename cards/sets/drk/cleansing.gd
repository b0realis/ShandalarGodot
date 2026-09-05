extends CardScript
## Cleansing — {W}{W}{W} — Sorcery — (drk, rare)
## Oracle: For each land, destroy that land unless any player pays 1 life.
##
## Implementation: the era's Armageddon-you-can-buy-off. Every land on the
## battlefield — both players' — is walked in turn, and each is ransomed
## for a single point of life that ANY player may pay. The offer goes in
## APNAP order (CR 101.4): the active player first, then the other, and the
## first yes saves that land.
##
## The land list is snapshotted before anything is destroyed, so a land
## that somehow arrives mid-resolution is not swept.
##
## "Unless ANY player pays 1 life" is offered to both seats in APNAP order
## through their own DecisionAgent, which is a real question for a human
## seat (the §1.3 pre-flight holds the resolution open on it) and the
## heuristic's own answer for every other. The default hint is "pay for
## your own lands, not the opponent's, and not at 1 life" — but it is only
## a hint: a seat that says yes at 1 life pays it and loses to the
## state-based actions, which is what CR 118.4 allows.


func build() -> CardData:
	return CardData.new("Cleansing", "{W}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(CleansingEffect.new()) \
		.oracle("For each land, destroy that land unless any player pays 1 life.")


class CleansingEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var lands: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst.is_land():
				lands.append(inst)
		for land in lands:
			if land.zone != Mtg.Zone.BATTLEFIELD:
				continue
			if not _ransomed(game, land):
				game.destroy(land)

	## Offer the point of life to each player in APNAP order; true when
	## somebody paid.
	static func _ransomed(game: MtgGame, land: CardInstance) -> bool:
		var order: Array[int] = [game.active_player, game.opponent_of(game.active_player)]
		for pid in order:
			if game.players[pid].has_lost or game.players[pid].life < 1:
				continue   # nothing left to pay with
			# The HINT (the heuristic seat's answer): pay for your own
			# lands, and not the last point of life. A seat that overrides
			# it may spend that last point — CR 118.4 permits it.
			var hint: bool = land.controller_id == pid \
				and game.players[pid].life > 1
			if game.agents[pid].choose_yes_no(game, pid,
					"Pay 1 life to save %s?" % land.data.card_name, hint):
				game.adjust_life(pid, -1)
				return true
		return false

	func describe() -> String:
		return "destroys each land unless a player pays 1 life for it"
