extends CardScript
## Fire and Brimstone — {3}{W}{W} — Instant — (drk, uncommon)
## Oracle: Fire and Brimstone deals 4 damage to target player who attacked
##         this turn and 4 damage to you.
##
## Implementation: "who attacked this turn" is a TARGETING restriction, so
## it lives in the TargetSpec (TargetSpec.with_player_filter, new) rather
## than in resolve() — a seat that did not attack is refused, and a seat
## whose attackers have all since died is still a legal target, which is
## why the record is on the PLAYER (MtgPlayer.attacked_this_turn) and not
## read off the creatures.
##
## The 4 to yourself is not a target and not optional: white's price for a
## Lightning Bolt and a half. It is dealt second, so a Circle of Protection
## put up in response protects against the half that is aimed at you.


func build() -> CardData:
	return CardData.new("Fire and Brimstone", "{3}{W}{W}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(4).target_player(_attacked_this_turn, \
			"target player who attacked this turn")) \
		.spell(DamageEffect.new(4).to_controller()) \
		.oracle("Fire and Brimstone deals 4 damage to target player who attacked "
			+ "this turn and 4 damage to you.")


static func _attacked_this_turn(game: MtgGame, pid: int) -> bool:
	return game.players[pid].attacked_this_turn
