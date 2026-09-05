extends CardScript
## Ghazbán Ogre — {G} — Creature — Ogre — 2/2 — (arn, common)
## Oracle: At the beginning of your upkeep, if a player has more life than
##         each other player, the player with the most life gains control
##         of this creature.
##
## Implementation: an UPKEEP_START trigger on ITS CONTROLLER's upkeep
## whose intervening "if" (re-checked at resolution, CR 603.4) demands a
## strict life leader; MtgGame.change_control hands the Ogre over. A 2/2
## for one mana that defects to whoever is winning — so the trick is to
## be behind on life while it beats down.


func build() -> CardData:
	return CardData.new("Ghazbán Ogre", "{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["ogre"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _defect,
			"At the beginning of your upkeep, if a player has more life than each "
			+ "other player, the player with the most life gains control of this creature.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, if a player has more life than each "
			+ "other player, the player with the most life gains control of this creature.")


## The intervening "if" (CR 603.4): checked HERE, when the ability would
## trigger, and again in `_defect` when it resolves. Tied life totals mean
## no player "has more life than each other player", so with a tie the
## ability must not go on the stack at all.
static func _own_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if int(event.data["player"]) != source.controller_id:
		return false
	return _life_leader(game) >= 0


static func _life_leader(game: MtgGame) -> int:
	var best := -1
	var best_life := -999
	var tied := false
	for p in game.players:
		if p.life > best_life:
			best_life = p.life
			best = p.id
			tied = false
		elif p.life == best_life:
			tied = true
	return -1 if tied else best


static func _defect(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var leader := _life_leader(game)
	if leader >= 0 and leader != source.controller_id:
		game.change_control(source, leader)
