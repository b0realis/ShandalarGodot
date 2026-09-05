extends CardScript
## Chains of Mephistopheles — {1}{B} — Enchantment — (leg, rare)
## Oracle: If a player would draw a card except the first one they draw in
##         each of their draw steps, that player discards a card instead. If
##         the player discards a card this way, they draw a card. If the
##         player doesn't discard a card this way, they mill a card.
##
## Implementation: a CR 614 replacement (CardData.draw_replacement) that
## applies to EVERY player, which is the whole point of the card — it turns
## a Braingeyser into a rummage and an Ancestral Recall into three of them.
##
## The exemption is the FIRST would-be draw of that player's own draw step
## (ctx.draw_number == 1 while ctx.in_draw_step), so a Howling Mine's extra
## card is caught and the ordinary one is not.
##
## The replacement's own "they draw a card" is not caught again: CR 614.5
## applies a replacement at most once to an event, and MtgGame enforces that
## with a re-entry guard while the callback runs. Without it the card is an
## infinite loop, which is exactly why it has a reputation.
##
## An empty hand means nothing can be discarded, so that player mills
## instead — the printed third sentence, and the reason Chains is a lock
## rather than a tax against an empty grip.
##
## mage-go does not implement Chains at all; there is no `@CHAINS` prompt in
## the 1997 tables either (Legends arrived with the expansion), so the
## discard uses the engine's own `@PROMPT_DISCARDACARD` funnel.


func build() -> CardData:
	return CardData.new("Chains of Mephistopheles", "{1}{B}",
			Mtg.CardType.ENCHANTMENT) \
		.replaces_draws(_chain) \
		.oracle("If a player would draw a card except the first one they draw in "
			+ "each of their draw steps, that player discards a card instead. If the "
			+ "player discards a card this way, they draw a card. If the player "
			+ "doesn't discard a card this way, they mill a card.")


static func _chain(game: MtgGame, _source: CardInstance, pid: int,
		ctx: Dictionary) -> bool:
	# "except the first one they draw in each of their draw steps"
	if bool(ctx["in_draw_step"]) and int(ctx["draw_number"]) == 1:
		return false
	if game.players[pid].hand.is_empty():
		game.log_line("%s has nothing to discard — Chains of Mephistopheles mills instead"
			% game.players[pid].player_name)
		game.mill(pid, 1)
		return true
	game.discard_cards(pid, game.agents[pid].choose_discard(game, pid, 1))
	# CR 614.5 keeps this new draw out of the Chains' own jaws.
	game.draw_cards(pid, 1)
	return true
