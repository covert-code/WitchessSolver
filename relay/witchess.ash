script "witchess.ash";
notify digitrev;
import <witchess_solver.ash>

buffer witchess(buffer page) {
	ws_loadSolutions();
	ws_page = page;
	ws_load();
	ws_setPuzzleTrueNum();
	ws_parse();

	if (ws_solns contains ws_puzzleTrueNum) {
		string ws_soln_str = ws_solns[ws_puzzleTrueNum];
		ws_submission = ws_dirsToCoords(ws_soln_str);
		page.replace_string("<input type=\"hidden\" value=\"\" name=\"sol\" id=\"sol\" />", "<input type=\"hidden\" value=\""+ws_submission+"\" name=\"sol\" id=\"sol\" />");
		string[int] coords = ws_submission.split_string("|");
		int[int,int] corners;
		foreach i, s in coords {
			page.replace_string("rel=\"" + s + "\"  class=\"hline\"", "rel=\"" + s + "\"  class=\"hline active\"");
			page.replace_string("rel=\"" + s + "\"  class=\"vline\"", "rel=\"" + s + "\"  class=\"vline active\"");
			string[int] xy = s.split_string(",");
			corners[xy[0].to_int()+1,xy[1].to_int()+1] += 1;
			corners[xy[0].to_int()+1,xy[1].to_int()-1] += 1;
			corners[xy[0].to_int()-1,xy[1].to_int()+1] += 1;
			corners[xy[0].to_int()-1,xy[1].to_int()-1] += 1;
		}
		foreach x, y, cnt in corners{
			if (cnt >= 2){
				string s = x.to_string + "," + y.to_string();
				page.replace_string("rel =\""+s+"\"  class=\"corner \"", "rel =\""+s+"\"  class=\"corner blown\"");
			}
		}
	}
}

void main() {
	visit_url().witchess().write();
}

/*
6,4 corner
6,3
6,5
7,4
5,4
*/