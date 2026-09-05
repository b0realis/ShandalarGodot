extends CardScript
## Hidden Path — {2}{G}{G}{G}{G} — Enchantment — (drk, rare)
## Oracle: Green creatures have forestwalk.
##
## Implementation: a global static appending "forest" to every GREEN
## creature's live landwalk — both players', as printed, though in
## practice only a green deck plays it. Six mana for "your team is
## unblockable" against anyone on Forests.


func build() -> CardData:
	return CardData.new("Hidden Path", "{2}{G}{G}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply, "Green creatures have forestwalk.")) \
		.oracle("Green creatures have forestwalk. (They can't be blocked as long as "
			+ "defending player controls a Forest.)")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.G) != 0 \
				and not inst.cur_landwalk.has("forest"):
			inst.cur_landwalk.append("forest")
