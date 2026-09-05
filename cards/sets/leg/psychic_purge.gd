extends CardScript
## Psychic Purge — {U} — Sorcery — (leg, common)
## Oracle: Psychic Purge deals 1 damage to any target.
##         When a spell or ability an opponent controls causes you to
##         discard this card, that player loses 5 life.
##
## Implementation: the second clause is a trigger that fires from the one
## zone no ability list reaches — a HAND. The engine's hook for it is
## CardData.on_discarded (new), called by MtgGame.discard_cards and
## discard_random as the card leaves, with the controller of whatever caused
## the discard (MtgGame.current_resolution_controller).
##
## "A spell or ability AN OPPONENT CONTROLS" is why the cause is passed: a
## Jalum Tome or a Bazaar of Baghdad you activate yourself costs nothing,
## and neither does the cleanup discard, which no spell or ability caused
## (cause_pid is -1 there).
##
## LIFE LOSS, not damage (CR 118.2): no prevention shield, no Circle, no
## Ali from Cairo floor applies to it.
##
## This is the card that made discard decks think twice in 1994 — a
## Hypnotic Specter hitting one costs its controller 5.


func build() -> CardData:
	return CardData.new("Psychic Purge", "{U}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(1).any_target()) \
		.triggers_when_discarded(_punish) \
		.oracle("Psychic Purge deals 1 damage to any target.\nWhen a spell or "
			+ "ability an opponent controls causes you to discard this card, that "
			+ "player loses 5 life.")


static func _punish(game: MtgGame, inst: CardInstance, pid: int,
		cause_pid: int) -> void:
	# Nobody caused it (the cleanup discard), or you caused it yourself.
	if cause_pid < 0 or cause_pid == pid:
		return
	game.log_line("%s is purged — %s loses 5 life" % [
		inst.data.card_name, game.players[cause_pid].player_name])
	game.adjust_life(cause_pid, -5)
