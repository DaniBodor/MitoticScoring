requires("1.53d");
setJustification("center");
setFont("SansSerif", 9, "antialiased");

notes_lines = 3;
surrounding_box = 1;	// in pixels

if(nImages > 0)		Overlay.remove;
else				open();

all_stages = newArray("G2", "NEBD", "Prophase", "Metaphase", "Anaphase", "Telophase", "Decondensation", "G1");
nAllStages = all_stages.length;
colorArray = newArray("white","red","green","blue","cyan","magenta","yellow","orange","pink");
progressOptions = newArray("Click OK","Draw only","Draw + t");
scoringOptions = newArray("None", "Load default", "Set new default");

default_array = newArray(
	"_", // 0 Value (ignored)
	"", //1 default_saveloc
	"", //2 default_expname
	3,  //3 default_timestep
	0,  //4 default_duplic
	0,  //5 default_zspread
	"red", //6 default_color1
	"white", //7 default_color2
	progressOptions[0], //8 default_promptOK
	getDir("file") + "DefaultObservationList.csv", // -2 default_obslist_location
	scoringOptions[1], // -1 default_scoring
	0,1,0,0,1,0,0,0); // default_stages
nDefaults = default_array.length;
//Array.print(default_array);	// for troubleshooting

// load previous defaults (if any)
defaults_dir = getDirectory("macros") + "MitoticScoringDefaults" + File.separator;
defaults_path = defaults_dir+ "DefaultSettings.txt";
if (!File.isDirectory(defaults_dir))	File.makeDirectory(defaults_dir);
if (File.exists(defaults_path)){
	loaded_str = File.openAsString(defaults_path);
	loaded_array = split(loaded_str, "\n");
	if (loaded_array.length == nDefaults){
		default_array = loaded_array;
	}
}
//Array.print(default_array);	// for troubleshooting

// open setup window
Dialog.create("Setup");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("OUTPUT SETTINGS");
	Dialog.addDirectory("Save location", default_array[1]);
	Dialog.addString("Experiment name",  default_array[2]);
	Dialog.setInsets(0, 0, 0);
	Dialog.addNumber("Time step", default_array[3]);

	Dialog.setInsets(25, 0, 0);
	Dialog.addMessage("SETTINGS FOR VISUAL TRACKING");
	Dialog.setInsets(3, 15, 5);
	Dialog.addChoice("Progress to next box by", progressOptions, default_array[8]);
	Dialog.setInsets(-3, 15, 5);
	Dialog.addChoice("ROI color of drawn box", colorArray, default_array[6]);
	Dialog.setInsets(0, 15, 5);
	Dialog.addChoice("ROI color of large box", colorArray, default_array[7]);
	Dialog.setInsets(0, 15, 0);
	Dialog.addNumber("Large box on +/-", default_array[5], 0, 1, "z-planes surrounding drawn box");
	Dialog.setInsets(3, 15, 0);
	Dialog.addCheckbox("Duplicate boxes left and right? "+
						"(for OrgaMovie output that contains the same organoid twice)",  default_array[4]);
	
	Dialog.setInsets(20, 0, 0);
	Dialog.addMessage("SCORING SETTINGS");
	Dialog.setInsets(0, 20, 0);
	Dialog.addChoice("Score observations?",  scoringOptions, default_array[nDefaults - nAllStages - 1]);
	Dialog.setInsets(2, 10, 0);
	Dialog.addMessage("Which mitotic stages should be monitored?")
	Dialog.setInsets(-5, 20, 0);
	default_stages = Array.slice(default_array, nDefaults - nAllStages, nDefaults);
	Dialog.addCheckboxGroup(2, 4, all_stages, default_stages);
	Dialog.addHelp("https://github.com/DaniBodor/MitoticScoring#setup");
Dialog.show();
	saveloc = Dialog.getString();
	expname = Dialog.getString();
		if (expname == "")	expname = "mitotic_scoring";
	timestep = Dialog.getNumber();
	
	box_progress = Dialog.getChoice();
	overlay_color1 = Dialog.getChoice();
	overlay_color2 = Dialog.getChoice();
	zboxspread = Dialog.getNumber();	
	dup_overlay = Dialog.getCheckbox();
	
	scoring = Dialog.getChoice();
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

// check input
nStages = stages_used.length;
if (nStages == 0)	exit("Macro aborted because no stages are tracked.\nSelect at least 1 stage to track");
if (!File.isDirectory(saveloc))		File.makeDirectory(saveloc);
if (!File.isDirectory(saveloc))		exit("Chosen save location does not exist; please choose valid directory");

// load observation list
obslist_path = default_array[nDefaults - nAllStages - 2]; 
if (scoring == scoringOptions[2] || !File.exists(obslist_path) ){
	obslist_path = File.openDialog("Choose new default observation list csv file");
	scoring = scoringOptions[1];
}
if (!endsWith(obslist_path, ".csv"))				exit("***ERROR***\nmake sure you choose an existing csv file as your observation list");
obsCSV = split(File.openAsString(obslist_path), "\n");

new_default = Array.concat(saveloc, expname, timestep, 
							dup_overlay, zboxspread, overlay_color1, overlay_color2, box_progress, 
							obslist_path, scoring, default_stages);

// save defaults for next time
Array.show(new_default);
selectWindow("new_default");
saveAs("Text", defaults_path);
run("Close");

// make headers string ##HEADERS##
init_headers = newArray("movie", "cell#");
interv_headers = newArray();
end_headers = newArray();

for (i = 0; i < nStages; i++) {
	init_headers[i+2] = "t"+i;
	if (i > 0)	interv_headers = Array.concat(interv_headers, "time_t" + i-1 + "-->t"+i);
	end_headers[i] = stages_used[i];
}
obs_headers = observationsDialog(obsCSV, "headers");
headers = Array.concat(init_headers, interv_headers, obs_headers, end_headers);

/*
Array.print(init_headers);
Array.print(interv_headers);
Array.print(obs_headers);
Array.print(end_headers);
Array.print(headers);
*/

headers_str = String.join(headers,"\t");
// load progress
table = "Scoring_" + expname + ".csv";
_table_ = "["+table+"]";
results_file = saveloc + table;
overlay_file = saveloc + getTitle() + "_overlay.zip";
loadPreviousProgress(headers_str);
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
	
	coordinates_array = newArray();
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {	// put box making into function?
		run("Select None");
		// allow user to box mitotic cell
		wait_string = "Draw a box around a cell at " + stages_used[tp] + " of mitotic event.";
		if (tp > 0) wait_string = wait_string + "\n ---- t" + tp-1 + " at frame " + f;
		
		if (box_progress == progressOptions[0]) {	// click OK to progress
			waitForUser(wait_string);	
		}
		else{	// draw box to progress
			// make new waiting log window
			if (isOpen("Waiting")){
				selectWindow("Waiting");
				run("Close");
			}
			run("Text Window...", "name=Waiting width=100 height=8 menu");
			setLocation(750, 200);
			wait_string = "*****Close this window to finish session\n" + wait_string;
			if (box_progress == progressOptions[2]){
				roiManager("reset");
				wait_string = wait_string + "\nPress t or add to ROI Manager when done"
			}
			print("[Waiting]", wait_string);
			
			while (keepWaiting() == 1){
				wait(250);
				if (!isOpen("Waiting"))	exit("Session finished.\nYou can carry on later using the same experiment name and settings");
			}
			
			run("Collect Garbage");
			if (isOpen("Waiting")){
				selectWindow("Waiting");
				run("Close");
			}
		}

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
		Stack.getPosition(_, z, f);
		overlay_coord = newArray(x, y, w, h, f, f, z, z);
		rearranged = newArray(x, y, x+w, y+h, f, z);
		coordinates_array = Array.concat(coordinates_array, rearranged);

		// create overlay of mitotic timepoint (t0, t1, etc)
		overlay_name = "c" + c + "_t" + tp;
		makeOverlay(overlay_coord, overlay_name, "red");
	}
	run("Select None");
	
	// reorganize coordinates
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhttzz = getFullSelectionBounds(reorganized_coord_array);
	
	// create box overlay of cells already analyzed (only on relevant slices)
	makeOverlay(xywhttzz, "c" + c, "white");	
	
	// for manual input on observations
	//events = GUI();

	// create and print results line
	// need to organize/comment on the below !!
	tps = newArray();
	intervals = newArray();
	for (i = 0; i < nStages; i++) {
		tps[i] = reorganized_coord_array[4*nStages+i];
		if (i > 0) intervals[i-1] = (tps[i] - tps[i-1]) * timestep;
	}

	observations = observationsDialog(obsCSV, "results");
	results = Array.concat(im, c, tps, intervals, observations);
	
	for (i = 0; i < nStages; i++){
		curr_coord = Array.slice(coordinates_array, i*rearranged.length, (i+1)*rearranged.length);
		coord_string = String.join(curr_coord,"_");
		results = Array.concat(results,coord_string);
	}
	xywhttzz_string = String.join(xywhttzz,"_");
	results = Array.concat(results, xywhttzz_string);

	results_str = String.join(results,"\t");
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


function reorganizeCoord(coord_group){
	reorganized = newArray();
	for (j = 0; j < coord_group.length/nStages; j++) {
		for (i = 0; i < coord_group.length; i+=rearranged.length) {
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
	xA = Array.concat( Array.slice( A, nStages*0, nStages*1), Array.slice( A, nStages*2, nStages*3));	
	yA = Array.concat( Array.slice( A, nStages*1, nStages*2), Array.slice( A, nStages*3, nStages*4));
	tA = Array.slice( A, nStages*4, nStages*5);
	zA = Array.slice( A, nStages*5, nStages*6);
	
	Array.getStatistics(xA, x_min, x_max, _, _);
	Array.getStatistics(yA, y_min, y_max, _, _);
	Array.getStatistics(tA, t_min, t_max, _, _);
	Array.getStatistics(zA, z_min, z_max, z_mean, _);

	w = x_max - x_min;
	h = y_max - y_min;

	xywhttzz = newArray(x_min, y_min, w, h, t_min, t_max, z_min, z_max);
	return xywhttzz;
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
			"lagger","bridge","misaligned", "cohesion defect", "apoptosis",
			"multipolar","#_poles","micronucleated","#_micronuclei","micronuclei_before/after_mitosis",
			"multinucleated","#_nuclei","multinucleated_before/after_mitosis",
			"other","namely",
			"unclear");
	
	for (nl = 0; nl < notes_lines; nl++) headers = Array.concat(headers,"notes"+nl+1);	// then add lines for notes
	headers = Array.concat(headers,stages_used);		// then coordinates of each mitotic stage
	headers = Array.concat(headers, "extract_code");	// then a code to allow for quick extraction (Gaby request)
	
	//Array.print(headers);
	headers = String.join(headers,"\t");
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

			new_filename = results_file + "_old";
			for (fn = 2; File.exists(saveloc + new_filename); fn++) {
				new_filename = results_file + "_old_" + fn;
			}
			
			waitForUser("***ERROR***\n" + 
			"Previous settings do not match current settings for this experiment (name)\n" +
			"The results file from the previous experiment will be saved as " + saveloc + new_filename + ",\n"+
			"and a new results file will be created for this experiment.\n" +
			"All previous regions will be deleted "
			vlkdngkjdfng	// need to do same for overlay windows! or at least not remove them
			"Alternatively, abort now [Esc] and restart experiment with a new experiment name");

			selectWindow(table);
			saveAs("Text", results_file);

			run("Close");
			return 1;
	} else	return 0;
}

function loadPreviousProgress(headers){

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
	// create rect at each frame
	//Array.print(coord);
	for (f = coord[4]; f <= coord[5]; f++) {
		for (i = 0; i < dup_overlay+1; i++) {	// 1 or 2 boxes, depending on dup_overlay
			Stack.getDimensions(_, _, ch, sl, fr);
			for (z = maxOf(1, coord[6] - zboxspread); z <= minOf(sl, coord[7] + zboxspread); z++) {
				x_coord = (coord[0] + getWidth()/2 * i) % getWidth();		// changes only if (i==1 && dup_coord==1)
				makeRectangle(x_coord, coord[1], coord[2], coord[3]);
				Roi.setName(name);
				Overlay.addSelection(color);
				
				// unfortunately Overlay.setPosition(c, z, t) only works if there's c (or z?) > 1
				if (ch*sl == 1)		Overlay.setPosition(f);
				else				Overlay.setPosition(0, z, f);
			}
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

function observationsDialog(CSV_lines, Results_Or_Header){
	out_order = newArray();
	Dialog.createNonBlocking("Score observations");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("Record your observations below");
	for (l = 1; l < CSV_lines.length; l++) {
		currLine = split(CSV_lines[l],",");
		
		if (currLine [0] == "Group") {
			Dialog.setInsets(10, 0, 0);
			Dialog.addMessage(currLine[1]);
		}
		
		else {
			curr_header = currLine[1].replace(" ","_");
			headers = Array.concat(headers, curr_header);
			
			Dialog.setInsets(0,10,0);
			choices =  Array.slice(currLine, 4, currLine.length);
			choices[0] = "";
			for (i = 0; i < choices.length; i++) {
				choices[i] = replace(choices[i], "\"", "");
				choices[i] = choices[i].trim;
			}
			
			// add main
			if (currLine [0] == "Checkbox"){
				Dialog.addCheckbox(currLine[1], 0);
				out_order = Array.concat(out_order,"chk");
			}
			if (currLine [0] == "Text"){
				Dialog.addString(currLine[1], "", 24);
				out_order = Array.concat(out_order,"str");
			}
			if (currLine [0] == "Number"){
				Dialog.addNumber(currLine[1], "");
				out_order = Array.concat(out_order,"num");
			}
			if (currLine [0] == "File"){
				Dialog.addFile(currLine[1], "");
				out_order = Array.concat(out_order,"str");
			}
			if (currLine [0] == "List"){
				Dialog.addChoice(currLine[1], choices);
				out_order = Array.concat(out_order,"opt");
			}
	
			// add extras
			if (currLine [2]){	// Add_#
				headers = Array.concat(headers, curr_header + "_#");
				Dialog.addToSameRow();
				Dialog.addString("#", "",1);
				out_order = Array.concat(out_order,"str");
			}
			if (currLine [3]){	// Add_Text
				headers = Array.concat(headers, curr_header+"_note");
				Dialog.addToSameRow();
				Dialog.addString("", "", 16);
				out_order = Array.concat(out_order,"str");
			}
			if (currLine [4]){	// Add_List
				headers = Array.concat(headers, curr_header+"_choice");
				Dialog.addToSameRow();
				Dialog.addChoice("", choices);
				out_order = Array.concat(out_order,"opt");
			}
		}
	}
	if (Results_Or_Header == "results") {
		Dialog.show();
		for (i = 0; i < out_order.length; i++) {
			if (out_order[i] == "chk")	output = Array.concat(output, Dialog.getCheckbox() );
			if (out_order[i] == "str")	output = Array.concat(output, Dialog.getString()   );
			if (out_order[i] == "num")	output = Array.concat(output, Dialog.getNumber()   );
			if (out_order[i] == "opt")	output = Array.concat(output, Dialog.getChoice()   );
		}
		return output;
	}
	else{
		return headers;
	}
}

function keepWaiting(){
	keep_waiting = 1;
	if (box_progress == progressOptions[1]) {
		getRawStatistics(area);
		if (area != getWidth()*getHeight() && area != 0)	keep_waiting = 0;
	}
	else if (roiManager("count") > 0)						keep_waiting = 0;

	return keep_waiting;
}
