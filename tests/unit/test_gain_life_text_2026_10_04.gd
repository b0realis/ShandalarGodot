extends GameTest
## GainLifeEffect's menu text agrees with its subject: "you gain 1 life",
## "target player gains 2 life" (it used to read "you gains" — found by the
## Mirage bug pass on 2026-10-04, Soul Shepherd).


func test_untargeted_gain_reads_you_gain() -> void:
	assert_eq(GainLifeEffect.new(1).describe(), "you gain 1 life")


func test_untargeted_loss_reads_you_lose() -> void:
	assert_eq(GainLifeEffect.new(-3).describe(), "you lose 3 life")


func test_targeted_gain_keeps_gains() -> void:
	assert_eq(GainLifeEffect.new(2).target_player().describe(), "target player gains 2 life")
