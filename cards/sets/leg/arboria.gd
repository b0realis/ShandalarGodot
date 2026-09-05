extends CardScript
## Arboria — {2}{G}{G} — World Enchantment — (leg, uncommon)
## Oracle: Creatures can't attack a player unless that player cast a spell
##         or put a nontoken permanent onto the battlefield during their
##         last turn.
##
## Implementation: a static that reads a new piece of per-seat bookkeeping —
## MtgPlayer.acted_last_turn, which MtgGame sets from cast_spell and
## _put_on_battlefield (only for actions taken on that player's OWN turn,
## which is what "during their last turn" means) and rolls over as each
## player's turn ends. Every seat carries its own history, so "their last
## turn" is the last turn THAT player took.
##
## In a duel the only player who can be attacked is the non-active one, so
## the static grounds every creature when that seat sat still. Tokens do not
## count, and neither does an instant cast on somebody else's turn —
## Arboria really does reward doing nothing, which is why it is a World
## Enchantment that both players want gone.
##
## The first turn of the game has no "last turn", so nobody may be attacked
## while Arboria is out — correct, and unreachable in practice since Arboria
## costs four.


func build() -> CardData:
	return CardData.new("Arboria", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(
			_peace, "Creatures can't attack a player unless that player cast a spell or put a nontoken permanent onto the battlefield during their last turn.")) \
		.oracle("Creatures can't attack a player unless that player cast a spell or "
			+ "put a nontoken permanent onto the battlefield during their last turn.")


static func _peace(game: MtgGame, _source: CardInstance) -> void:
	# The only player who can be attacked right now is the defender.
	var defender := game.opponent_of(game.active_player)
	if game.players[defender].acted_last_turn:
		return
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_cant_attack = true
