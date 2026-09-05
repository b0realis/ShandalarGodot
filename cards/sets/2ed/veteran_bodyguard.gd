extends CardScript
## Veteran Bodyguard — {3}{W}{W} — Creature — Human — 2/5 — (2ed, rare)
## Oracle: As long as this creature is untapped, all damage that would be
##         dealt to you by unblocked creatures is dealt to this creature
##         instead.
##
## Implementation: a redirection registered on its controller
## (MtgPlayer.combat_damage_redirect, rebuilt each recalculation like
## Martyrs of Korlis' artifact redirect). MtgGame.deal_damage checks that
## the source really is an UNBLOCKED attacker before sending the blow this
## way, so a blocked creature's trample damage still gets through.


func build() -> CardData:
	return CardData.new("Veteran Bodyguard", "{3}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 5) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(_stand_guard,
			"As long as this creature is untapped, all damage that would be dealt to you by unblocked creatures is dealt to this creature instead.")) \
		.oracle("As long as this creature is untapped, all damage that would be dealt to you by unblocked creatures is dealt to this creature instead.")


static func _stand_guard(game: MtgGame, source: CardInstance) -> void:
	if source.tapped:
		return
	game.players[source.controller_id].combat_damage_redirect = source.id
