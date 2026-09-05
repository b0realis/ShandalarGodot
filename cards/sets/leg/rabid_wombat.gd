extends CardScript
## Rabid Wombat — {2}{G}{G} — Creature — Wombat — 0/1 — (leg, uncommon)
## Oracle: Vigilance
##         This creature gets +2/+2 for each Aura attached to it.
##
## Implementation: printed vigilance plus a self-referential static
## counting the AURAS in its attachments list. Every aura is worth its own
## bonus PLUS the Wombat's +2/+2, which is why the card was the Legends
## aura deck's whole reason to exist.


func build() -> CardData:
	return CardData.new("Rabid Wombat", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["wombat"]) \
		.with_keywords([Mtg.Keyword.VIGILANCE]) \
		.static_ability(StaticAbility.new(
			_apply, "Rabid Wombat gets +2/+2 for each Aura attached to it.")) \
		.oracle("Vigilance\nThis creature gets +2/+2 for each Aura attached to it.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var auras := 0
	for aura_id in source.attachments:
		var aura := game.find_instance(aura_id)
		if aura != null and aura.zone == Mtg.Zone.BATTLEFIELD and aura.data.is_aura():
			auras += 1
	source.cur_power += 2 * auras
	source.cur_toughness += 2 * auras
