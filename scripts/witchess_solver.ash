script "witchess_solver.ash";

/**********************************************
                 Developed by:
      the coding arm of ProfessorJellybean.
             (#2410942), (#2413598)

          GCLI Usage: witchess_solver
      mgithub & docs: https://goo.gl/v14FCu

**********************************************/

/*****************************************
                 FIELDS
      things to remember as we go
*****************************************/

// Whether or not we should look for the minimum path (by default, false).
// Activate with "set solvewitchess_golf = true"
boolean ws_golf = false || get_property("ws_golf").to_boolean();

// Whether or not we should log solutions (by default, false).
// Activate with "set solvewitchess_log_soln = true"
boolean ws_log_soln = false || get_property("ws_log_soln").to_boolean();

// Current witchess puzzle in scope
int ws_puzzleNum = 0;

// Current witchess puzzle's true number
int ws_puzzleTrueNum = 0;

// Your password hash, for POST requests.
string ws_pwhash = "&pwd=" + my_hash();

/*****************************************
                 UTILS
         little tools to help us
*****************************************/

// Color of error messages.
string ws_errcolor = "Red";

// Prints an error.
void ws_throwErr(string errmsg) {
	print(errmsg, ws_errcolor);
}

/*****************************************
                LOADING
        asking for the problem
*****************************************/

// Buffer that represents the current puzzle
buffer ws_page;

// Regex matcher for detecting whether or not the current puzzle is solved
string ws_matcher_done_regex = "Solved Today";
matcher ws_matcher_done = create_matcher(ws_matcher_done_regex, ws_page);

// Regex matcher for detecting whether or not the current puzzle has a next.
string ws_matcher_hasNext_regex = "next";
matcher ws_matcher_hasNext = create_matcher(ws_matcher_hasNext_regex, ws_page);

// Regex matcher for detecting the current puzzle's true number.
string ws_matcher_trueNum_regex = "Witchess Puzzle #(\\d+)";
matcher ws_matcher_trueNum = create_matcher(ws_matcher_trueNum_regex, ws_page);

// Whether or not the current puzzle is solved.
boolean ws_puzzleDone() {
	string prop_name = "_ws_finished_" + ws_puzzleNum;
	if (ws_puzzleNum == 0) {
		return true;
	} else if (get_property(prop_name).to_boolean()) {
		return true;
	} else {
		reset(ws_matcher_done, ws_page);
		if (ws_matcher_done.find()) {
			set_property(prop_name, true);
			return true;
		} else {
			return false;
		}
	}
}

// Whether or not the current puzzle has a next.
boolean ws_puzzleHasNext() {
	if (ws_puzzleNum == 0) {
		return true;
	} else {
		reset(ws_matcher_hasNext, ws_page);
		if (ws_matcher_hasNext.find()) {
			return true;
		} else {
			return false;
		}
	}
}

// Gets the true number of the puzzle.
void ws_setPuzzleTrueNum() {
	ws_matcher_trueNum.reset(ws_page);
	ws_matcher_trueNum.find();
	ws_puzzleTrueNum = ws_matcher_trueNum.group(1).to_int();
}

// Forwards the count.
void ws_next() {
	ws_puzzleNum += 1;
}

// Gets the puzzle.
void ws_load() {
	ws_page = visit_url("witchess.php?num=" + ws_puzzleNum);
	ws_setPuzzleTrueNum();
}

// Gets the next puzzle.
void ws_loadNext() {
	ws_next();
	ws_load();
}

/*****************************************
                PARSING
        understanding the problem
*****************************************/
// The length of the puzzle.
int ws_puzzleDimX = 0;

// The height of the puzzle.
int ws_puzzleDimY = 0;

// Matcher for the end square (x long)
string ws_matcher_end_square_regex = '(\\d+)\"\\W+class=\"corner end\"';
matcher ws_matcher_end_square = create_matcher(ws_matcher_end_square_regex, ws_page);

// Matcher for the end square (y long)
string ws_matcher_start_square_regex = '(\\d+),0\"\\W+class=\"corner start\"';
matcher ws_matcher_start_square = create_matcher(ws_matcher_start_square_regex, ws_page);

// Sets the correct dimensions
void ws_setPuzzleMaxLims() {
	if (ws_puzzleNum > 0) {
		reset(ws_matcher_end_square, ws_page);
		reset(ws_matcher_start_square, ws_page);
		ws_matcher_end_square.find();
		ws_matcher_start_square.find();
		ws_puzzleDimX = ws_matcher_end_square.group(1).to_int() / 2;
		ws_puzzleDimY = ws_matcher_start_square.group(1).to_int() / 2;
	}
}

// Parses the current puzzle in ws_page. STUB
void ws_parse() {
	ws_setPuzzleMaxLims();
}

/*****************************************
                SOLVING
          solving the problem
*****************************************/
// Lookup table of known solutions
string ws_soln_path = "witchess_puzzle_solns.txt";

// Solution map
string[int] ws_solns;

// String of GET coordinates
string ws_submission = "";

// Buffer of GET coordinate response
buffer ws_submission_response;

// Loads the solution map into the current session
void ws_loadSolutions() {
	file_to_map(ws_soln_path , ws_solns);
}

// Matcher for the dir-to-coord conversion over the current puzzle
matcher ws_matcher_rludConvert = create_matcher("([rlud])", "");

// Converts a set of dirs for the current puzzle to a coordinate set.
string ws_dirsToCoords(string dirs) {
	dirs = to_lower_case(dirs);
	int x = ws_puzzleDimY * 2;
	int y = 0;
	int writeX = 0;
	int writeY = 0;

	int move = 0;

	int[string] witchess_path; 

	ws_matcher_rludConvert.reset(dirs);
	while (ws_matcher_rludConvert.find()) {
		string dir = ws_matcher_rludConvert.group(1);
		switch (dir) {
			case "r":
				writeY = y + 1;
				y = writeY + 1;
				writeX = x;
				break;
			case "l":
				writeY = y - 1;
				y = writeY - 1;
				writeX = x;
				break;
			case "u":
				writeX = x - 1;
				x = writeX - 1;
				writeY = y;
				break;
			case "d":
				writeX = x + 1;
				x = writeX + 1;
				writeY = y;
				break;
			default:
				ws_throwErr("Unrecognized direction: \"" + dir + "\"");
				break;
		}

		move += 1;

		if (x < 0 || x > ws_puzzleDimY * 2 || y < 0 || y > ws_puzzleDimX * 2) {
			ws_throwErr("Solution out of bounds! x:" + x + " y:" + y);
			ws_throwErr("dimX: " + ws_puzzleDimX + " dimY:" + ws_puzzleDimY);
			ws_throwErr("Error occurs at move " + move);
			return "";
		}
		witchess_path[writeX + "," + writeY] = 0;
	}

	if (x != 0 || y != ws_puzzleDimX * 2) {
		ws_throwErr("Solution does not correctly terminate! x:" + x + " y:" + y);
		ws_throwErr("dimX: " + ws_puzzleDimX + " dimY:" + ws_puzzleDimY);
	}

	sort witchess_path by index;

	string result = "";
	foreach coord, val in witchess_path {
		result += "|" + coord;
	}

	return result.substring(1);
}

// Submits the solution with a GET request.
void ws_submit() {
	string post_url = "witchess.php?sol=" + ws_submission + "&ajax=1&number=" + ws_puzzleTrueNum;
	print(post_url);
	ws_submission_response = visit_url(post_url, false);
}

// Solves the current puzzle in ws_page.
void ws_solve() {
	if (ws_solns contains ws_puzzleTrueNum) {
		string ws_soln_str = ws_solns[ws_puzzleTrueNum];
		ws_submission = ws_dirsToCoords(ws_soln_str);
		print("Solution: " + ws_soln_str + " -> " + ws_submission);
		ws_submit();
	} else {
		ws_throwErr("Solution for #"+ ws_puzzleTrueNum +" not found in lookup!");
	}
	ws_load();
}

/*****************************************
                SANITY
         checking our answers
*****************************************/
// Matcher for the square-sanity check
matcher ws_matcher_soln_sanity = create_matcher("([rlud])", "");

// tests whether or not a given solution string is rectangular. (static)
boolean ws_is_rect(string soln) {
	int x = 0;
	int y = 0;
	int maxX = 0;
	int maxY = 0;
	boolean sane = true;
	ws_matcher_soln_sanity.reset(soln);
	while (ws_matcher_soln_sanity.find()) {
		string dir = ws_matcher_soln_sanity.group(1);
		switch (dir) {
			case "r":
				y += 1;
				break;
			case "l":
				y -= 1;
				break;
			case "u":
				x += 1;
				break;
			case "d":
				x -= 1;
				break;
			default:
				ws_throwErr("Unrecognized direction: \"" + dir + "\"");
				break;
		}
		sane = sane && !(x < 0 || y < 0);
		maxX = max(x, maxX);
		maxY = max(y, maxY);
	}
	// sane = (x == y) && sane; // Some puzzles are discovered to be non-square.
	sane = (x == maxX) && sane;
	sane = (y == maxY) && sane;
	if (!sane) {
		print("x : " + x);
		print("y : " + y);
		print("x+: " + maxX);
		print("y+: " + maxY);
	}
	return sane;
}

/*****************************************
                MAIN
        lights, camera, action!
*****************************************/

// Attempts all the witchess puzzles and returns true if successful.
boolean ws_run() {
	boolean success = true;
	ws_loadSolutions();
	foreach key in ws_solns {
		if (!ws_is_rect(ws_solns[key])) {
			ws_throwErr("Warning: non-rect-bounded solution at key " + key);
		}
	}
	while (ws_puzzleHasNext()) {
		ws_loadNext();
		if (!ws_puzzleDone()) {
			ws_parse();
			ws_solve();
		}
		if (!ws_puzzleDone()) {
			ws_throwErr("Could not solve puzzle " + ws_puzzleNum + ". (#" + ws_puzzleTrueNum + ")");
			success = false;
		} else {
			print("Puzzle " + ws_puzzleNum + " complete. (#" + ws_puzzleTrueNum + ")", "green");
		}
	}
	
	return success;
}

void main() {
	if (ws_run()) {
		print("Witchess puzzles finished.", "green");
	} else {
		ws_throwErr("Could not complete all witchess puzzles.");
	}
}
