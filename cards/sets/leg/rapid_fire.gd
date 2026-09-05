extends CardScript
## Rapid Fire — {3}{W} — Instant — (leg, rare)
## Oracle: Cast this spell only before blockers are declared.
##         Target creature gains first strike until end of turn. If it
##         doesn't have rampage, that creature gains rampage 2 until end of
##         turn. (Whenever the creature becomes blocked, it gets +2/+2
##         until end of turn for each creature blocking it beyond the
##         first.)
##
## Implementation: one effect, so the spell takes ONE target. The rampage
## rider reads CardInstance.cur_rampage — the LIVE value, so a creature
## already wearing a granted rampage (a Gabriel Angelfire who chose it this
## upkeep) is not given a second one, exactly as printed.
##
## THE TIMING RIDER is enforced (CardData.castable_only_when): "before
## blockers are declared" is any step earlier than the declare-blockers
## step, so the beginning of combat and the declare-attackers step are the
## windows that matter, main phase one is legal too, and everything from
## the declare-blockers step onward is refused. Note it does NOT say
## "during combat" — the Blaze of Glory / Disharmony wording does, and this
## one deliberately does not.
##
## mage-go deviates: its Rapid Fire carries "XXX: timing restriction not
## enforced", so it can be cast at any time. Duel.hlp does not cover it —
## the shipped help file is the base game's pool.


func build() -> CardData:
	return CardData.new("Rapid Fire", "{3}{W}", Mtg.CardType.INSTANT) \
		.castable_only_when(_before_blockers) \
		.spell(RapidFireEffect.new()) \
		.oracle("Cast this spell only before blockers are declared.\nTarget "
			+ "creature gains first strike until end of turn. If it doesn't have "
			+ "rampage, that creature gains rampage 2 until end of turn. (Whenever "
			+ "the creature becomes blocked, it gets +2/+2 until end of turn for "
			+ "each creature blocking it beyond the first.)")


static func _before_blockers(game: MtgGame, _pid: int) -> String:
	if Mtg.STEP_ORDER.find(game.current_step()) \
			>= Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS):
		return "cast Rapid Fire only before blockers are declared"
	return ""


class RapidFireEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(inst.id, 0, 0,
			[Mtg.Keyword.FIRST_STRIKE])
		if inst.cur_rampage <= 0:
			game.continuous.add_until_eot_rampage(inst.id, 2)
		game.recalculate()

	func describe() -> String:
		return "target creature gains first strike, and rampage 2 if it has none"
