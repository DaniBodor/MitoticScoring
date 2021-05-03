notes_lines = 3;
surrounding_box = 8;	// in pixels
requires("1.53d");

if(nImages > 0)		Overlay.remove;
else				open();


mitotic_stages = newArray("NEBD", "Metaphase", "Anaphase_onset", "Decondensation", "Telophase", "G1");
totStages = mitotic_stages.length;
stages_used = newArray(0);

// load previous defaults (if any)
default_saveloc = "";
default_expname = "";
default_stages = newArray(1,0,1,0,0,0);
defaults_path = getDirectory("macros") + "OrgaMovie_Scoring_defaults.txt";
if (File.exists(defaults_path)){
	loaded_str = File.openAsString(defaults_path);
	loaded_array = split(loaded_str, "\n");
	default_saveloc = loaded_array[1];
	default_expname = loaded_array[2];
	loaded_stages = Array.slice(loaded_array, 3, totStages+4);
	if (loaded_stages.length == totStages)	default_stages = loaded_stages;
}

// open dialog to ask which stages to inlcude
t=0;
Dialog.create("Setup");
	Dialog.setInsets(0, 0, 0);
	Dialog.addDirectory("Save location", default_saveloc);
	Dialog.addString("Experiment name",  default_expname);
	Dialog.setInsets(20, 0, 0);
	Dialog.addMessage("Which mitotic stages should be monitored?")
	Dialog.setInsets(0, 0, 0);
	Dialog.addCheckboxGroup(2, 3, mitotic_stages, default_stages);
Dialog.show();
saveloc = Dialog.getString();
expname = Dialog.getString();
if (expname == "")	expname = "AnalysisOf" + makeDateOrTimeString("d");
new_default = newArray(saveloc, expname);
for (i = 0; i < totStages; i++) {	
	new_default[i+2] = Dialog.getCheckbox();
	if (new_default[i+2])	{
		curr_header = "t" + t + "_" + mitotic_stages[i];
		stages_used = Array.concat(stages_used, curr_header);
		t++;
	}
}
// save defaults for next time
Array.show(new_default);
selectWindow("new_default");
saveAs("Text", defaults_path);
run("Close");
nStages = stages_used.length;

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
else{
	prev_im = "";
	prev_c = 0;
}

// analyze individual events

setTool("rectangle");
for (c = prev_c+1; c > 0; c++){	// loop through cells
	im = getTitle();
	if (im != prev_im)	c = 1;
	prev_im = im;
	
	coordinates_array = newArray(0);
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {
		// allow user to box mitotic cell
		waitForUser("Draw a box around a cell at " + stages_used[tp] + " of mitotic event.");

		// get coordinates
		current_coord = getCoordinates();
		coordinates_array = Array.concat(coordinates_array, current_coord);

		// create overlay of mitotic timepoint (t0, t1, etc)
		setColor("red");
		x_mid = (current_coord[0] + current_coord[2])/2;
		Overlay.drawString("t"+tp, x_mid-6, current_coord[1]-1);
		Overlay.setPosition(getSliceNumber());
	}
	run("Select None");

	// reorganize coordinates for output
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhtt = getFullSelectionBounds(reorganized_coord_array);
	
	intervals = newArray(nStages-1);
	for (i = 0; i < intervals.length; i++) {
		intervals[i] = reorganized_coord_array[4*nStages+i+1] - reorganized_coord_array[4*nStages+i];
	}
	
	// create box overlay of cells already analyzed (only on relevant slices)
	setColor("white");
	for (t = xywhtt[4]; t <= xywhtt[5]; t++) {
		Overlay.drawRect(xywhtt[0], xywhtt[1], xywhtt[2], xywhtt[3]);
		Overlay.setPosition(t);
		Overlay.add;
	}
	Overlay.show;
	
	// custom function to ask for manual input on mitotic events
	events = GUI(notes_lines);

	// create and print results line
	results = Array.concat(im, c, intervals);
	results = Array.concat(results,events);
	
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
	
	// save results progress
	selectWindow(table);
	saveAs("Text", results_file);

	// save overlay
	run("To ROI Manager");
	roiManager("Show All without labels");
	roiManager("deselect");
	roiManager("save", saveloc + getTitle() + "_overlay.zip");
	run("From ROI Manager");
	roiManager("delete");
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
		Dialog.addChoice("SKIP THIS CELL?", no_yes);
		Dialog.addMessage("If not, register observations for this mitosis below:");
		Dialog.addChoice("Highlight cell", no_yes);
		
		Dialog.addMessage("");
		Dialog.addCheckbox("Lagger", 0);
		Dialog.addCheckbox("Bridge", 0);
		Dialog.addCheckbox("Misaligned", 0);
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
		
	Dialog.show();
		skip = Dialog.getChoice;
		highlighted = Dialog.getChoice;
		lag = Dialog.getCheckbox;
		bridge = Dialog.getCheckbox;
		misaligned = Dialog.getCheckbox;
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
		lag,		bridge,				misaligned,
		multipole,	pole_number,
		micronuc,	micronuc_number,	micronuc_timing,
		multinuc,	multinuc_number,	multinuc_timing,
		other_obs,	other_type,
		unclear
		);
	
	GUI_result = Array.concat(GUI_result, notes);

	return GUI_result;
}


function getCoordinates(){
	getSelectionBounds(x, y, w, h);
	t = getSliceNumber();

	coord = newArray(x, y, x+w, y+h, t);
	return coord;
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
	x_min = getMinOrMaxOfMultiple( Array.slice( A, nStages*0, nStages*1), "min");
	y_min = getMinOrMaxOfMultiple( Array.slice( A, nStages*1, nStages*2), "min");
	x_max = getMinOrMaxOfMultiple( Array.slice( A, nStages*2, nStages*3), "max");
	y_max = getMinOrMaxOfMultiple( Array.slice( A, nStages*3, nStages*4), "max");
	
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
	for (s = 1; s < nStages; s++) {		// then add the individual intervals
		t_header = "time_t" + s-1 + "-->t" + s;
		headers = Array.concat(headers,t_header);
	}
	
	headers = Array.concat(headers,	// then add the possible events
		newArray(	
			"skip","highlight",
			"lagger","bridge","misaligned",
			"multipolar","#_poles","micronucleated","#_micronuclei","micronuclei_before/after_mitosis",
			"multinucleated","#_nuclei","multinucleated_before/after_mitosis",
			"other","namely",
			"unclear"));
	
	for (nl = 0; nl < notes_lines; nl++) headers = Array.concat(headers,"notes"+nl);	// then add lines for notes
	headers = Array.concat(headers,stages_used);		// then coordinates of each mitotic stage
	headers = Array.concat(headers, "extract_code");	// then a code to allow for quick extraction (Gaby request)
	
	//Array.print(headers);
	headers = arrayToString(headers,"\t");
	return headers;
}

function checkHeaders(new){
//	selectWindow(table);
	old = Table.headings(table);

	if (old != new){
		exit("***ERROR***\n" + 
		"Previous settings of mitotic stages to include for this experiment do not match current settings.\n" +
		"Please manually move/rename/delete the file and restart macro, or restart macro with identical settings as before.\n\n" + 
		"Results file: " + results_file);
	}
}

function loadPreviousProgress(){
	headers = generateHeaders();

	// find previous logfile
	if (File.exists(results_file)){
		Table.open(results_file);
		checkHeaders(headers);
	}
	else if (isOpen(table)){	// if no previous log file, but scoring table is open
		checkHeaders(headers);
	}
	else{						// no previous log file and no current open scoring table
		run("Table...", "name="+_table_+" width=1200 height=300");
		print(_table_, "\\Headings:" + headers);
	}
	
	// find previous overlay
	if (File.exists(overlay_file)){
		roiManager("Open", overlay_file);
		run("From ROI Manager");
		roiManager("delete");
	}
}