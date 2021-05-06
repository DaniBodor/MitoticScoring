requires("1.53d");
setJustification("center");
setFont("SansSerif", 9, "antialiased");

notes_lines = 3;
surrounding_box = 1;	// in pixels

if(nImages > 0)		Overlay.remove;
else				open();

all_stages = newArray("G2", "NEBD", "Prophase", "Metaphase", "Anaphase", "Telophase", "Decondensation", "G1");
nAllStages = all_stages.length;


// load previous defaults (if any)
default_saveloc = "";
default_expname = "";
default_timestep = 3;
default_duplic  = 0;
default_color1 = "red";
default_color2 = "white";
default_score = 1;
default_stages = newArray(0,1,0,0,1,0,0,0);
defaults_path = getDirectory("macros") + "OrgaMovie_Scoring_defaults.txt";

if (File.exists(defaults_path)){
	loaded_str = File.openAsString(defaults_path);
	loaded_array = split(loaded_str, "\n");
	default_saveloc  = loaded_array[1];
	default_expname  = loaded_array[2];
	default_timestep = loaded_array[3];
	default_duplic   = loaded_array[4];
	default_color1	 = loaded_array[5];
	default_color2	 = loaded_array[6];
	default_score	 = loaded_array[7];
	loaded_stages = Array.slice(loaded_array, loaded_array.length-nAllStages, loaded_array.length);
	if (loaded_stages.length == nAllStages)	default_stages = loaded_stages;
}

// open dialog to ask which stages to inlcude
Dialog.create("Setup");
	Dialog.addDirectory("Save location", default_saveloc);
	Dialog.addString("Experiment name",  default_expname);
	Dialog.setInsets(0, 0, 0);
	Dialog.addNumber("Time step", default_timestep);
	Dialog.setInsets(20, 0, 0);
	Dialog.addCheckbox("Duplicate tracking ROIs left and right? "+
						"(for OrgaMovie output that contains the same organoid twice)",  default_duplic);
	Dialog.addString("ROI color at timepoint", default_color1);
	Dialog.addString("ROI color throughout", default_color2);
	Dialog.setInsets(20, 0, 0);
	Dialog.addCheckbox("Score observations?",  default_score);
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Which mitotic stages should be monitored?")
	Dialog.setInsets(0, 0, 0);
	Dialog.addCheckboxGroup(2, 4, all_stages, default_stages);
	Dialog.addHelp("https://github.com/DaniBodor/MitoticScoring#setup");
Dialog.show();
	saveloc = Dialog.getString();
	expname = Dialog.getString();
		if (expname == "")	expname = "AnalysisOf" + makeDateOrTimeString("d");
	timestep = Dialog.getNumber();
	dup_overlay = Dialog.getCheckbox();
	overlay_color1 = Dialog.getString();
	overlay_color2 = Dialog.getString();
	scoring = Dialog.getCheckbox();
	stages_used = newArray();
	t=0;
	for (i = 0; i < nAllStages; i++) {
		default_stages[i] = Dialog.getCheckbox();
		if (default_stages[i]) {
			curr_header = "t" + t + "_" + all_stages[i];
			stages_used[t] = curr_header;
			t++;
		}
	}
	
new_default = Array.concat(saveloc, expname, timestep, 
							dup_overlay, overlay_color1, overlay_color2, 
							scoring, default_stages);

nStages = stages_used.length;
if (nStages == 0)	exit("Macro aborted because no stages are tracked.\nSelect at least 1 stage to track");

// save defaults for next time
Array.show(new_default);
selectWindow("new_default");
saveAs("Text", defaults_path);
run("Close");


// load progress
table = "Scoring_" + expname + ".csv";
_table_ = "["+table+"]";
results_file = saveloc + table;
overlay_file = saveloc + getTitle() + "_overlay.zip";
loadPreviousProgress();
if	(Table.size > 0){
	prev_im =	Table.getString	("movie", Table.size-1);
	prev_c =	Table.get		("cell#", Table.size-1);
}
else {
	prev_im = "";
	prev_c = 0;
}

// analyze individual events

setTool("rectangle");
for (c = prev_c+1; c > 0; c++){	// loop through cells
	
	coordinates_array = newArray(0);
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {
		// allow user to box mitotic cell
		wait_string = "Draw a box around a cell at " + stages_used[tp] + " of mitotic event.";
		if (tp > 0) wait_string = wait_string + "\n ---- t" + tp-1 + " at frame " + f;
		waitForUser(wait_string);

		im = getTitle();
		if (tp == 0 && im != prev_im){
			c = 1;
			prev_im = im;
			Stack.getDimensions(_, _, ch, sl, fr);
			if (fr == 1){
				Stack.setDimensions(ch, fr, sl);
				Stack.getDimensions(_, _, ch, sl, fr);
			}
		}

		// get coordinates
		getSelectionBounds(x, y, w, h);
		Stack.getPosition(_, _, f);
		current_coord = newArray(x, y, w, h, f);
		rearranged = newArray(x, y, x+w, y+h, f);
		coordinates_array = Array.concat(coordinates_array, rearranged);

		// create overlay of mitotic timepoint (t0, t1, etc)
		overlay_name = "c" + c + "_t" + tp;
		makeOverlay(current_coord, overlay_name, "red");
	}
	run("Select None");
	
	// reorganize coordinates
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhtt = getFullSelectionBounds(reorganized_coord_array);
	
	// create box overlay of cells already analyzed (only on relevant slices)
	makeOverlay(xywhtt, "c" + c, "white");	
	
	// for manual input on observations
	events = GUI(notes_lines);

	// create and print results line
	tps = newArray();
	intervals = newArray();
	for (i = 0; i < nStages; i++) {
		tps[i] = reorganized_coord_array[4*nStages+i];
		if (i>0)	intervals[i-1] = (tps[i] - tps[i-1]) * timestep;
	}
	
	results = Array.concat(im, c, tps, intervals, events);
	
	for (i = 0; i < nStages; i++){
		curr_coord = Array.slice(coordinates_array, i*5, i*5+5);
		coord_string = arrayToString(curr_coord,"_");
		results = Array.concat(results,coord_string);
	}
	xywhtt_string = arrayToString(xywhtt,"_");
	results = Array.concat(results,xywhtt_string);

	//Array.print(results);
	results_str = arrayToString(results,"\t");
	print(_table_, results_str);
	
	// save overlay
	run("To ROI Manager");
	roiManager("Show All without labels");
	roiManager("deselect");
	roiManager("save", saveloc + getTitle() + "_overlay.zip");
	run("From ROI Manager");
	roiManager("delete");
	
	// save results progress
	selectWindow(table);
	saveAs("Text", results_file);

}


////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////
////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////
////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////

function GUI(nNotes){	
	/* 
	 *  This function creates a dialog window to generate manual input on mitotic events occuring in this cell.
	 *  This is ugly and non-modular and requires manual tinkering whenever things change. 
	 *  Don't have a good idea how to easily fix this without screwing up the formatting.
	 */
	
	// pre-sets
	time_option = newArray("","before_div","after_div","both");
	no_yes = newArray("NO","YES");
	notes = newArray(nNotes);

	// actual dialog/GUI
	Dialog.createNonBlocking("Observations checklist");
		Dialog.addMessage("Do you want to skip analysis for this cell?");
		Dialog.setInsets(0,20,0);
		Dialog.addCheckbox("Skip this cell", 0);
		Dialog.addMessage("If not, register observations for this mitosis below:");
		Dialog.setInsets(0,20,0);
		Dialog.addCheckbox("Highlight cell", 0);
		
		Dialog.addMessage("Record observations below");
		Dialog.addCheckbox("Lagger", 0);
		Dialog.addCheckbox("Bridge", 0);
		Dialog.addCheckbox("Misaligned", 0);
		Dialog.addCheckbox("Cohesion_defect", 0);
		Dialog.addCheckbox("Multipolar", 0);
			Dialog.setInsets(-20,120,0);
			Dialog.addString("#","",1);
		Dialog.addCheckbox("Micronucleus", 0);
			Dialog.setInsets(-20,120,0);
			Dialog.addString("#","",1);
			Dialog.addToSameRow();
			Dialog.addChoice("when",time_option);
		Dialog.addCheckbox("Multinucleated", 0);
			Dialog.setInsets(-20,120,0);
			Dialog.addString("#","",1);
			Dialog.addToSameRow();
			Dialog.addChoice("when",time_option);
		Dialog.addCheckbox("Other:", 0);
			Dialog.setInsets(-20,-100,0);
			Dialog.addString("","",22);
		Dialog.addCheckbox("Unclear", 0);
		//Dialog.addMessage("");
		for (i = 0; i < nNotes; i++) Dialog.addString("Notes","",22);
		
	if(scoring)		Dialog.show();
		skip = Dialog.getCheckbox;
		highlighted = Dialog.getCheckbox;
		lag = Dialog.getCheckbox;
		bridge = Dialog.getCheckbox;
		misaligned = Dialog.getCheckbox;
		cohesion_defect = Dialog.getCheckbox;
		multipole = Dialog.getCheckbox;
			pole_number = Dialog.getString;
		micronuc = Dialog.getCheckbox;
			micronuc_number = Dialog.getString;
			micronuc_timing = Dialog.getChoice;
		multinuc = Dialog.getCheckbox;
			multinuc_number = Dialog.getString;
			multinuc_timing = Dialog.getChoice;
		other_obs = Dialog.getCheckbox;
			other_type = Dialog.getString;
		unclear = Dialog.getCheckbox;
		for (i = 0; i < nNotes; i++) 	notes[i] = Dialog.getString;

	GUI_result = newArray(
		skip,		highlighted,
		lag,		bridge,				misaligned,			cohesion_defect,
		multipole,	pole_number,
		micronuc,	micronuc_number,	micronuc_timing,
		multinuc,	multinuc_number,	multinuc_timing,
		other_obs,	other_type,
		unclear
		);
	
	GUI_result = Array.concat(GUI_result, notes);

	return GUI_result;
}




function reorganizeCoord(coord_group){
	reorganized = newArray(0);
	for (j = 0; j < coord_group.length/nStages; j++) {
		for (i = 0; i < coord_group.length; i+=5) {
			reorganized = Array.concat(reorganized, coord_group[i+j]);
		}
	}
	return reorganized;
}

function getMinOrMaxOfMultiple(array,MinOrMax){
	// find out whether min or max
	if		(MinOrMax == "min" || MinOrMax == "MIN" || MinOrMax == "Min" || MinOrMax == "-" || MinOrMax == "--") multipl = -1;
	else if (MinOrMax == "max" || MinOrMax == "MAX" || MinOrMax == "Max" || MinOrMax == "+" || MinOrMax == "++") multipl =  1;
	else if (MinOrMax == -1 || MinOrMax == 1)	multipl = MinOrMax;
	else	exit("MinOrMax set incorrectly, as: " + MinOrMax);

	// find max value (or lowest negative value)
	return_value = array[0] * multipl;
	for (i = 1; i < array.length; i++) {
		current_test = array[i] * multipl;
		return_value = maxOf(current_test, return_value);
	}
	return_value = return_value * multipl;
	return return_value;
}

function getFullSelectionBounds(A){
	x_min = getMinOrMaxOfMultiple( Array.slice( A, nStages*0, nStages*1), "min") - surrounding_box;
	y_min = getMinOrMaxOfMultiple( Array.slice( A, nStages*1, nStages*2), "min") - surrounding_box;
	x_max = getMinOrMaxOfMultiple( Array.slice( A, nStages*2, nStages*3), "max") + surrounding_box;
	y_max = getMinOrMaxOfMultiple( Array.slice( A, nStages*3, nStages*4), "max") + surrounding_box;
	
	t_min = getMinOrMaxOfMultiple( Array.slice( A, nStages*4, nStages*5), "min");
	t_max = getMinOrMaxOfMultiple( Array.slice( A, nStages*4, nStages*5), "max");

	w = x_max - x_min;
	h = y_max - y_min;

	xywhtt = newArray(x_min,y_min,w,h,t_min,t_max);
	return xywhtt;
}

function arrayToString(A,splitter){
	string = "";
	for (i = 0; i < A.length; i++) {
		string = string + A[i] + splitter;
	}
	string = substring(string, 0, lastIndexOf(string, splitter));
	return string;
}

function makeDateOrTimeString(DorT){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);

	if(DorT == "date" || DorT == "Date" || DorT == "DATE" || DorT == "D" || DorT == "d"){
		y = substring (d2s(year,0),2);

		if (month > 8)	m = d2s(month+1,0);
		else			m = "0" + d2s(month+1,0);

		if (dayOfMonth > 9)		d = d2s(dayOfMonth,0);
		else					d = "0" + d2s(dayOfMonth,0);

		string = y + m + d;
	}

	if(DorT == "time" || DorT == "Time" || DorT == "TIME" || DorT == "T" || DorT == "t"){
		if (hour > 9)	h = d2s(hour,0);
		else			h = "0" + d2s(hour,0);

		if (minute > 9)	m = d2s(minute,0);
		else			m = "0" + d2s(minute,0);

		if (second > 9)	s = d2s(second,0);
		else			s = "0" + d2s(second,0);

		string = h + ":" + m + ":" + s;
	}

	return string;
}

function generateHeaders(){
	// create and print headers for output
	headers = newArray("movie","cell#");	// first entry of headers

	// add tps
	for (s = 0; s < nStages; s++) {		// then add the individual intervals
		tnumber = "t"+s;
		headers = Array.concat(headers,tnumber);
	}
	
	for (s = 1; s < nStages; s++) {		// then add the individual intervals
		t_header = "time_t" + s-1 + "-->t" + s;
		headers = Array.concat(headers,t_header);
	}
	
	headers = Array.concat(headers,	// then add the possible events
			"skip","highlight",
			"lagger","bridge","misaligned", "cohesion defect",
			"multipolar","#_poles","micronucleated","#_micronuclei","micronuclei_before/after_mitosis",
			"multinucleated","#_nuclei","multinucleated_before/after_mitosis",
			"other","namely",
			"unclear");
	
	for (nl = 0; nl < notes_lines; nl++) headers = Array.concat(headers,"notes"+nl+1);	// then add lines for notes
	headers = Array.concat(headers,stages_used);		// then coordinates of each mitotic stage
	headers = Array.concat(headers, "extract_code");	// then a code to allow for quick extraction (Gaby request)
	
	//Array.print(headers);
	headers = arrayToString(headers,"\t");
	return headers;
}

function checkHeaders(new){
	selectWindow(table);
	old = Table.headings();
	if (Table.size() == 0){
		run("Close");
		return 1;
	} else if (old != new){
			//print("_" + old);
			//print("_" + new);
			waitForUser("***ERROR***\n" + 
			"Previous settings of mitotic stages to include for this experiment do not match current settings and the results table will be overwritten if the macro is not aborted.\n  \n" +
			"Either abort macro (hit 'Esc') before analyzing any cell and restart using a different experiment name, or manually move/rename the previous results file to avoid overwriting it\n" + 
			"Results file: " + results_file);
			run("Close");
			return 1;
	} else	return 0;
}

function loadPreviousProgress(){
	headers = generateHeaders();

	// find previous results
	if (File.exists(results_file)){
		Table.open(results_file);
		make_table_now = checkHeaders(headers);
	}
	else if (isOpen(table)){	// if no previous log file, but scoring table is open
		make_table_now = checkHeaders(headers);
	}
	else make_table_now = 1; // no previous log file and no current open scoring table
	
	if (make_table_now){					
		run("Table...", "name="+_table_+" width=1200 height=300");
		print(_table_, "\\Headings:" + headers);
		Overlay.remove();
	}
	
	// find previous overlay
	else if (File.exists(overlay_file)){
		roiManager("Open", overlay_file);
		run("From ROI Manager");
		roiManager("delete");
	}
}

function makeOverlay(coord, name, color){
	// if single timepoint is given, make this both first and last timepoint
	if (coord.length < 6)	coord[5] = coord[4];

	// create rect at each frame
	for (f = coord[4]; f <= coord[5]; f++) {
		for (i = 0; i < dup_overlay+1; i++) {	// 1 or 2 boxes, depending on dup_overlay
			x_coord = (coord[0] + getWidth()/2 * i) % getWidth();		// changes only if (i==1 && dup_coord==1)
			makeRectangle(x_coord, coord[1], coord[2], coord[3]);
			Roi.setName(name);
			Overlay.addSelection(color);
			// unfortunately Overlay.setPosition(c, z, t) only works if there's c (or z?) > 1
			if(ch*sl > 1)	Overlay.setPosition(0, 0, f);
			else			Overlay.setPosition(f);
		}
	}
	run("Select None");
	
	// display and format overlay
	Overlay.show;
	Overlay.useNamesAsLabels(1);
	Overlay.drawLabels(1);
	Overlay.setLabelFontSize(8,"scale");
	Overlay.setLabelColor(color);
}
