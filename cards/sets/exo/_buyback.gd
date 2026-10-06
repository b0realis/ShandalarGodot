extends RefCounted
## Exodus (_buyback, Pack 9). Buyback (CR 702.27): spells that return to their owner's hand when the buyback cost was paid.
##
## Buyback is a PAYMENT ROW (CardData.with_buyback, engine package E2) —
## see cards/sets/tmp/_buyback.gd. Exodus prints the non-mana buybacks:
## "Sacrifice a land", "Discard two cards", "Pay 4 life" and "Pay 3 life,
## Discard a card at random" (E7's random-discard object cost: rolled on
## the game's RNG as it is paid, never the spell itself). Memory Crystal
## is E2's buyback discount (its generic part only, every player's).
## Tests: tests/cards/test_pack_9_B2_buyback.gd,
## test_pack_9_B2_buyback_sth_exo.gd, test_pack_9_B2_ai.gd (Flowstone Flood).
const OC := preload("res://engine/additional_object_costs.gd")

## The least life the AI keeps after paying Flowstone Flood's 3 (the line
## AiPlayer.BUYBACK_LIFE_FLOOR draws for every life buyback).
const FLOOD_LIFE_FLOOR := 10

static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Allay":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _enchantment)))
			c.with_buyback({"mana": "{3}"})
		"Pegasus Stampede":
			var pegasus := CreateTokenEffect.new("Pegasus", 1, 1, Mtg.ManaColor.W, "pegasus")
			pegasus.token.with_keywords([Mtg.Keyword.FLYING])
			c.spell(pegasus)
			c.with_buyback({"object_costs": [OC.sacrificing("a land", _land)], "text": "Sacrifice a land"})
		"Reaping the Rewards":
			c.spell(GainLifeEffect.new(2))
			c.with_buyback({"object_costs": [OC.sacrificing("a land", _land)], "text": "Sacrifice a land"})
		# ------------------------------------------------------------- blue
		"Forbid":
			c.spell(CounterEffect.new())
			c.with_buyback({"object_costs": [OC.discarding("card", Callable(), 2)], "text": "Discard two cards"})
		# ------------------------------------------------------------ black
		"Slaughter":
			c.spell(DestroyEffect.new(TargetSpec.creature("target nonblack creature", _nonblack), false))
			c.with_buyback({"life": 4, "text": "Pay 4 life"})
		# -------------------------------------------------------------- red
		"Flowstone Flood":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land)))
			c.with_buyback({"life": 3, "object_costs": [OC.discarding_at_random()],
				"text": "Pay 3 life, Discard a card at random"})
			c.with_ai_mode(_flood_mode)
		"Shattering Pulse":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _artifact)))
			c.with_buyback({"mana": "{3}"})
		# --------------------------------------------------------- artifact
		"Memory Crystal":
			c.with_buyback_modifier(_crystal)
		_: return false
	return true


static func _land(i: CardInstance) -> bool: return i.is_land()
static func _artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func _nonblack(i: CardInstance) -> bool: return (i.cur_colors & Mtg.ManaColor.B) == 0


## "Buyback costs cost {2} less." — every player's buyback, its generic
## part only, never below zero (the Memory Crystal rulings; MtgGame applies
## the floor). Not optional.
static func _crystal(_g: MtgGame, _pid: int, _spell: CardData, _source: CardInstance) -> int:
	return -2


## THE AI's ROW FOR FLOWSTONE FLOOD (the printed row 0, the buyback row 1).
## The generic buyback reading (AiPlayer._buyback_row) prices an object it
## cannot see at a flat half point, and a card discarded AT RANDOM is not
## that: it is the average card of the rest of the hand. So the card says
## it itself, from its controller's own hand and life only (fair play):
## buy back when the row is payable now, the 3 life leaves
## [constant FLOOD_LIFE_FLOOR] or more, and the average card the roll can
## take is worth less than the Flood itself. The two rows cost the same
## mana, so no other card is starved by the choice.
static func _flood_mode(g: MtgGame, pid: int) -> int:
	var me := g.players[pid]
	if me.life - 3 < FLOOD_LIFE_FLOOR: return 0
	var flood: CardInstance = null
	var others := 0
	var worth := 0.0
	for card in me.hand:
		if flood == null and card.data.card_name == "Flowstone Flood":
			flood = card
			continue
		others += 1
		worth += Evaluator.card_value(card.data)
	if flood == null or others == 0: return 0
	var rows := flood.data.buyback_rows()
	if rows.is_empty() or g.payment_row_refusal(pid, flood, rows[0]) != "": return 0
	return rows[0] if worth / others < Evaluator.card_value(flood.data) else 0
