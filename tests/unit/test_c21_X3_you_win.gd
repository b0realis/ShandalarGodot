extends GameTest
## "YOU WIN!", NOT "YOU WINS!" (0.50.66 bug campaign, leftover). The
## Gauntlet seated the human as "You" ([GauntletScreen]), and the duel's
## last log line — [method MtgGame._lose]'s "<loser> loses: <why>. <winner>
## wins!" — read "You wins!" and "You loses: …" there. The Gauntlet seats
## them by their Magic Battle name now (tests/ui/test_c21_X3_gauntlet_name.gd);
## a seat still called "You" — typed so, or a duel recorded before — takes
## its own verb at the end; every other seat's name reads as before.


func _ending() -> String:
	for line in g.log_lines:
		if String(line).contains("conceded"):
			return String(line)
	return ""


func test_the_human_seat_named_you_wins() -> void:
	g.players[0].player_name = "You"
	g.players[1].player_name = "Arzakon"
	assert_ok(g.concede(1))
	assert_eq(_ending(), "Arzakon loses: conceded. You win!")


func test_the_human_seat_named_you_loses() -> void:
	g.players[0].player_name = "You"
	g.players[1].player_name = "Arzakon"
	assert_ok(g.concede(0))
	assert_eq(_ending(), "You lose: conceded. Arzakon wins!")


func test_any_other_name_reads_as_before() -> void:
	assert_ok(g.concede(1))
	assert_eq(_ending(), "P1 loses: conceded. P0 wins!", "a name is a third person")
	assert_eq(g.winner, 0)
