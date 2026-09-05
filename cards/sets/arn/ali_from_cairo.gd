extends CardScript
## Ali from Cairo — {2}{R}{R} — Creature — Human — 0/1 — (arn, rare)
## Oracle: Damage that would reduce your life total to less than 1 reduces
##         it to 1 instead.
##
## Implementation: a static writing its controller's
## MtgPlayer.min_life_from_damage, which MtgGame.deal_damage clamps
## against. Only DAMAGE is floored — Mirror Universe, a Lich's sacrifice
## or drawing from an empty library still finish the job, exactly as
## printed.


func build() -> CardData:
	return CardData.new("Ali from Cairo", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Damage that would reduce your life total to less than 1 reduces it to 1 "
			+ "instead.")) \
		.oracle("Damage that would reduce your life total to less than 1 reduces it "
			+ "to 1 instead.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	game.players[source.controller_id].min_life_from_damage = 1
