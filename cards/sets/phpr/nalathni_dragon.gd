extends CardScript
## Nalathni Dragon — {2}{R}{R} — Creature — Dragon — 1/1 — (phpr, rare)
## Oracle: Flying; banding (Any creatures with banding, and up to one
##         without, can attack in a band. Bands are blocked as a group. If
##         any creatures with banding you control are blocking or being
##         blocked by a creature, you divide that creature's combat damage,
##         not its controller, among any of the creatures it's being blocked
##         by or is blocking.)
##         {R}: This creature gets +1/+0 until end of turn. If this ability
##         has been activated four or more times this turn, sacrifice this
##         creature at the beginning of the next end step.
##
## Implementation: Dragon Whelp's fuse on a 1/1 flying bander — the same
## card-local breath count stamped with the turn it belongs to, because
## "four or more times THIS TURN" must reset while CardInstance.memory does
## not. The fourth breath schedules a delayed end-step SACRIFICE, which
## regeneration and indestructible cannot stop (CR 701.17).
##
## Attack bands are implemented; DEFENSIVE banding is not (engine-wide,
## docs/ROADMAP.md), so the granted keyword does here what banding does
## everywhere in this engine: the Dragon may attack in a band.
##
## WHY THIS CARD IS FILED UNDER `phpr`: it is a promo, but not a HarperPrism
## book promo — it was given out at DragonCon 1994 and Scryfall files it as
## set `pdrc`. Our `phpr` folder is the pool's PROMO bucket (the deck
## builder already labels it "Promotional"), and the record is fetched from
## its real `pdrc` printing by tools/fetch_cards.py's EXTRA_PRINTINGS, which
## keeps `printed_in: pdrc` on the data so the origin is never lost. No
## rules code reads the set code except City in a Bottle and Golgothian
## Sylex, and neither asks about promos.
##
## That it belongs in the 1997 pool at all is settled by `Duel.hlp`, the
## game's own shipped help, which carries its card entry verbatim:
## *"Casting Cost: 2rr / Color: Red / Type: Summon Dragon / Power/Toughness:
## 1/1 / Banding, flying / {R}: Nalathni Dragon gets +1/+0 until end of
## turn. If {R}{R}{R}{R} or more is spent in this way during one turn, bury
## Nalathni Dragon at end of turn."*


func build() -> CardData:
	return CardData.new("Nalathni Dragon", "{2}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.BANDING]) \
		.activated(ActivatedAbility.new("{R}", false, [BreathEffect.new()],
			"{R}: This creature gets +1/+0 until end of turn. If this ability has been activated four or more times this turn, sacrifice this creature at the beginning of the next end step.")) \
		.oracle("Flying; banding (Any creatures with banding, and up to one without, "
			+ "can attack in a band. Bands are blocked as a group. If any creatures "
			+ "with banding you control are blocking or being blocked by a creature, "
			+ "you divide that creature's combat damage, not its controller, among "
			+ "any of the creatures it's being blocked by or is blocking.)\n{R}: This "
			+ "creature gets +1/+0 until end of turn. If this ability has been "
			+ "activated four or more times this turn, sacrifice this creature at "
			+ "the beginning of the next end step.")


class BreathEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(source.id, 1, 0)
		game.recalculate()
		# The count resets with the turn: nothing else clears card memory
		# between turns, so the turn number is stored beside it.
		var burns := 1
		if int(source.memory.get("breaths_turn", -1)) == game.turn_number:
			burns = int(source.memory.get("breaths", 0)) + 1
		source.memory["breaths"] = burns
		source.memory["breaths_turn"] = game.turn_number
		if burns >= 4:
			game.doom_at_next_end_step(source, false, false, true)

	func describe() -> String:
		return "gets +1/+0 until end of turn; the fourth breath is fatal"
