extends CardScript
## Angry Mob — {2}{W}{W} — Creature — Human — 2+*/2+* — (4ed, uncommon)
## Oracle: Trample
##         During your turn, Angry Mob's power and toughness are each equal
##         to 2 plus the number of Swamps your opponents control. During
##         turns other than yours, Angry Mob's power and toughness are each 2.
##
## Implementation: a characteristic-defining static (layer 7b) that reads
## LIVE land types — so a Swamp made by Evil Presence, Cyclopean Tomb or a
## Magical Hack feeds the mob just like a printed one.


func build() -> CardData:
	return CardData.new("Angry Mob", "{2}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.static_ability(StaticAbility.new(_count_swamps,
			"During your turn, its power and toughness are each equal to 2 plus the number of Swamps your opponents control.").setting_base_pt()) \
		.oracle("Trample\nDuring your turn, Angry Mob's power and toughness are each equal to 2 plus the number of Swamps your opponents control. During turns other than yours, Angry Mob's power and toughness are each 2.")


static func _count_swamps(game: MtgGame, source: CardInstance) -> void:
	var size := 2
	if game.active_player == source.controller_id:
		for inst in game.players[game.opponent_of(source.controller_id)].battlefield:
			if inst.is_land() and inst.has_subtype("swamp"):
				size += 1
	source.cur_power = size
	source.cur_toughness = size
