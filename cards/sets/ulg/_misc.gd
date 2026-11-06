extends RefCounted
## Urza's Legacy (_misc, Pack 10). Everything else: global effects and
## one-off rules — the cards each built on one small engine package.
##
## - Multani's Presence (Pack 10 E4, Mtg.EventType.SPELL_COUNTERED): "a
##   spell you've cast" is the event's caster (the stack controller, not
##   the owner) and never a copy (a copy is not cast, CR 707.10). A fizzle
##   is no counter (CR 608.2b): nothing is drawn for it.
## - Damping Engine (Pack 10 E9): the player who controls MORE permanents
##   than each other player — counted live at every play — can't play lands
##   or cast artifact, creature or enchantment spells (CR 601.3, 305.2);
##   that player alone is offered the special action "sacrifice a permanent
##   to ignore it until end of turn" (CR 116.2d; Pack 9's ignore action,
##   its payer named by the Engine). Equal counts bind nobody.
## tests/cards/test_pack_10_B13_*.gd pin each card.

const COUNTERED := Mtg.EventType.SPELL_COUNTERED


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Multani's Presence":
			c.triggered(TriggeredAbility.new(COUNTERED, _presence_draw,
				"Whenever a spell you've cast is countered, draw a card.", _your_cast_spell))
		"Damping Engine":
			c.bans_playing(_damping_ban).ignorable_by_sacrifice("permanent", Callable(), _most_permanents)
		_: return false
	return true


# ------------------------------------------------------ Multani's Presence --

static func _your_cast_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.get("controller", -1)) == s.controller_id and not bool(e.data.get("is_copy", false))


static func _presence_draw(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	g.draw_cards(g.controller_acting_for(s), 1)


# ----------------------------------------------------------- Damping Engine --

## "A player who controls more permanents than each other player": that
## seat, or -1 when nobody does (equal counts).
static func _most_permanents(g: MtgGame, _s: CardInstance) -> int:
	var a := g.players[0].battlefield.size()
	var b := g.players[1].battlefield.size()
	return 0 if a > b else (1 if b > a else -1)


static func _damping_ban(g: MtgGame, pid: int, data: CardData, source: CardInstance) -> bool:
	if _most_permanents(g, source) != pid or g.effect_ignored_by(source, pid):
		return false
	return data.is_land() or data.is_creature() or data.is_type(Mtg.CardType.ARTIFACT) \
		or data.is_type(Mtg.CardType.ENCHANTMENT)
