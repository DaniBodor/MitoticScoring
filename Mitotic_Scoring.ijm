// MITOTIC SCORING MACRO v1.21

// general stuff
requires("1.53f");
setJustification("center");
setFont("SansSerif", 9, "antialiased");

if (isOpen("Waiting")){
	selectWindow("Waiting");
	run("Close");
}

if (Table.size > 0){
	T = Table.title;
	selectWindow(T);
	run("Close");
}

// variables used in code below
all_stages = newArray("G2", "NEBD", "Prophase", "Metaphase", "Anaphase", "Telophase", "Decondensation", "G1");
nAllStages = all_stages.length;
colorArray = newArray("white","red","green","blue","cyan","magenta","yellow","orange","pink");
progressOptions = newArray("Draw + t", "Draw only");	//, "Click OK");
scoringOptions = newArray("None", "Default", "Custom");
overlay_file = "";


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
obslist_path = default_array[nDefaults - nAllStages - 2];
//Array.print(default_array);	// for troubleshooting

if(nImages > 0)		Overlay.remove;
else				open();

// open setup window
Dialog.create("Setup");
	Dialog.setInsets(0, 0, 0);
	Dialog.addMessage("GENERAL SETTINGS");
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
	Dialog.addNumber("Draw box on ", default_array[5], 0, 1, "Z-planes above and below indicated plane");
	Dialog.setInsets(3, 15, 0);
	Dialog.addCheckbox("Duplicate boxes left and right? "+
						"(for OrgaMovie output that contains the same organoid twice)",  default_array[4]);

	Dialog.setInsets(20, 0, 0);
	Dialog.addMessage("SCORING SETTINGS");
	Dialog.setInsets(0, 20, 0);
	Dialog.addChoice("Score observations",  scoringOptions, default_array[nDefaults - nAllStages - 1]);
	Dialog.setInsets(-3, 50, 0);
	Dialog.addMessage("If you select  'Custom', another window will pop up after this to select file");
	Dialog.setInsets(2, 10, 0);
	Dialog.addMessage("Which mitotic stages should be monitored?")
	Dialog.setInsets(-5, 20, 0);
	default_stages = Array.slice(default_array, nDefaults - nAllStages, nDefaults);
	Dialog.addCheckboxGroup(2, 4, all_stages, default_stages);
	Dialog.addHelp("https://github.com/DaniBodor/MitoticScoring#setup");
Dialog.show();
	saveloc = Dialog.getString();
	expname = Dialog.getString();
		if (expname == "")	expname = "Mitotic_Scoring";
	timestep = Dialog.getNumber();

	box_progress = Dialog.getChoice();
	overlay_color1 = Dialog.getChoice();
	overlay_color2 = Dialog.getChoice();
	zboxspread = Dialog.getNumber();
	dup_overlay = Dialog.getCheckbox();

	scoring = Dialog.getChoice();
	stages_used = newArray();
	t = 0;
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
if (nStages == 0)					exit("Macro aborted because no stages are tracked.\nSelect at least 1 stage to track");
if (!File.isDirectory(saveloc))		File.makeDirectory(saveloc);
if (!File.isDirectory(saveloc))		exit("Chosen save location does not exist; please choose valid directory");

// load observation list
if (scoring == scoringOptions[2] || !File.exists(obslist_path) ){	// either select new default OR default file not found
	Dialog.create("Choose observation list");
	Dialog.addFile("Choose csv file for custom observation list", "");
	Dialog.addMessage("This list will be the default for future experiments " +
	"(so next time you can select 'default' to use this list)");
	Dialog.addMessage(	"Note that this window can pop up the first time you run the macro (or after moving macro files),\n" +
						"irrespective of choice for scoring Default / Custom / None");

	Dialog.show();
	obslist_path = Dialog.getString();

	if (scoring == scoringOptions[2]) scoring = scoringOptions[1];
}

if (!endsWith(obslist_path, ".csv") || !File.exists(obslist_path))				exit("***ERROR***\nmake sure you choose an existing csv file as your observation list");
obsCSV = split(File.openAsString(obslist_path), "\n");
//for (i = 0; i < obsCSV.length; i++) print(i, obsCSV[i]);

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
	for (j = 0; j < i; j++) {
		interv_headers = Array.concat(interv_headers, "time_t" + i-j-1 + "-->t"+i);
	}
	end_headers[i] = stages_used[i];
}
obs_headers = observationsDialog(obsCSV, "headers");
headers = Array.concat(init_headers, interv_headers, obs_headers, end_headers, "extract_code");

headers_str = String.join(headers,"\t");


// load progress
table = expname + "_Scoring.csv";
if (isOpen(table)){
	selectWindow(table);
	run("Close");
}
_table_ = "["+table+"]";
results_file = saveloc + table;
overlay_file_prefix = saveloc + expname + "_ROIs_";
overlay_file = overlay_file_prefix + getTitle() + ".zip";
loadPreviousProgress(headers_str);
if	(Table.size > 0){
	prev_im =	Table.getString	("movie", Table.size-1);
	prev_c =	Table.get		("cell#", Table.size-1);
}
else {
	prev_im = "no_prev_im";
	prev_c = 0;
}


// analyze individual events
setTool("rectangle");
for (c = prev_c+1; c > 0; c++){	// loop through cells

	coordinates_array = newArray();
	skipArray = newArray(nStages);
	nSkip = 0;
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {
		run("Select None");
		// allow user to box mitotic cell

		// generate wait window information
		wait_string =	"*****Close this window to finish session*****\n\n" +
						"Draw a box around a cell at " + stages_used[tp] + " of mitotic event";
		if (box_progress == progressOptions[0]){	// draw + t
			roiManager("reset");
			wait_string = wait_string + " and press 't' or add to ROI Manager";
		}
		if (nSkip < tp)		wait_string = wait_string + "\n ---- t" + tp-nSkip-1 + " at frame " + overlay_coord[4];
		wait_string = wait_string + "\nIf you close all images, a window will pop up asking you to open a new image file";
		wait_string = wait_string + "\n\nType 'skip' or 'SKIP' in whis window if you don't have an entry for this stage";

		// generate wait window under image
		getLocationAndSize(im_x, im_y, im_w, im_h);
		run("Text Window...", "name=Waiting width=100 height=10 menu");
		setLocation(im_x, im_y + im_h);
		print("[Waiting]", wait_string + "\n");
		selectWindow("Waiting");

		// wait for drawing a box
		while (keepWaiting())	wait(250);
		selectWindow("Waiting");
		run("Close");
		run("Collect Garbage");

		// fix entry numbers, etc
		im = getTitle();
		if (tp == 0 && im != prev_im ){
			if (Table.size == 0)	c = 1;
			else{
				imArray = Table.getColumn("movie");
				filtered = Array.filter(imArray, im);
				c = filtered.length + 1;
			}
			prev_im = im;
			Stack.getDimensions(_, _, ch, sl, fr);
			if (fr == 1){
				Stack.setDimensions(ch, fr, sl);
				Stack.getDimensions(_, _, ch, sl, fr);
				resaveTif();
			}
		}

		// get data from box
		if (selectionType == -1) {	// if no selection (i.e. skipped)
			x=NaN;y=NaN;w=NaN;h=NaN;f=NaN;z=NaN;
			nSkip ++;
			skipArray[tp] = 1;
		}
		else {
			// get coordinates
			getSelectionBounds(x, y, w, h);
			if (dup_overlay)	x = x % (getWidth()/2);
			Stack.getPosition(_, z, f);

			// create overlay of mitotic timepoint (t0, t1, etc)
			overlay_coord = newArray(x, y, w, h, f, f, z, z);
			overlay_name = "c" + c + "_t" + tp;
			makeOverlay(overlay_coord, overlay_name, overlay_color1);
		}

		// rearrange and store coordinates
		rearranged = newArray(x, y, x+w, y+h, f, z);
		coordinates_array = Array.concat(coordinates_array, rearranged);
	}
	run("Select None");

	// reorganize coordinates
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhttzz = getFullSelectionBounds(reorganized_coord_array);

	// create box overlay of cells already analyzed (only on relevant slices)
	makeOverlay(xywhttzz, "c" + c, overlay_color2);

	// create and print results line
	// need to organize/comment on the below !!
	tps = newArray();
	intervals = newArray();

	for (i = 0; i < nStages; i++) {
		if (skipArray[i])	tps[i] = NaN;
		else 				tps[i] = reorganized_coord_array[4*nStages+i];

		for (j = 0; j < i; j++) {
			intervals = Array.concat(intervals, (tps[i] - tps[i-j-1]) * timestep);
		}
	}

	observations = observationsDialog(obsCSV, "results");

	//Array.print(observations);
	if (observations.length > 0){
		results = Array.concat(im, c, tps, intervals, observations);

		for (i = 0; i < nStages; i++){
			curr_coord = Array.slice(coordinates_array, i*rearranged.length, (i+1)*rearranged.length);
			coord_string = String.join(curr_coord,"_");
			results = Array.concat(results,coord_string);
		}
		xywhttzz_string = String.join(xywhttzz,"_");
		results = Array.concat(results, xywhttzz_string);

		updateTable(Table.size);

		// save overlay
		run("To ROI Manager");
		roiManager("Show All without labels");
		roiManager("deselect");
		overlay_file = overlay_file_prefix + getTitle() + ".zip";
		roiManager("save", overlay_file);

		// save results progress
		selectWindow(table);
		saveAs("Text", results_file);
	}
	else {	// i.e. REMOVE CURRENT INPUT
		removeOverlays(c);
		c--;
	}

	if( roiManager("count") > 0 )	run("From ROI Manager");
	close("ROI Manager");
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
	Array.getStatistics(zA, z_min, z_max, _, _);

	w = x_max - x_min;
	h = y_max - y_min;

	xywhttzz = newArray(x_min, y_min, w, h, t_min, t_max, z_min, z_max);
	return xywhttzz;
}


function loadPreviousProgress(headers){
	// find previous results
	if (File.exists(results_file)){
		Table.open(results_file);
		make_table_now = 0; //checkHeaders(headers);
	}
	else make_table_now = 0;

	if (make_table_now){
		// %%%%%%%%%%%%%%%%%%%
		run("Table...", "name="+_table_+" width=1200 height=300");
		print(_table_, "\\Headings:" + headers);
		Overlay.remove();
	}

	// find previous overlay
	overlay_file = overlay_file_prefix + getTitle() + ".zip";
	findPrevOverlay(overlay_file);
}


function checkHeaders(new){
	selectWindow(table);
	old = Table.headings();
	if (Table.size() == 0)		run("Close");
	else if (old != new){
		// fix table order

	}
}



function makeOverlay(coord, name, color){
	// create rect at each frame
	//Array.print(coord);
	for (f = coord[4]; f <= coord[5]; f++) {
		for (i = 0; i < dup_overlay+1; i++) {	// 1 or 2 boxes, depending on dup_overlay
			Stack.getDimensions(_, _, ch, sl, fr);
			for (z = maxOf(1, coord[6] - zboxspread); z <= minOf(sl, coord[7] + zboxspread); z++) {

				// fix sizes for duplicate overlay images
				X = (coord[0] + getWidth()/2 * i) % getWidth();		// changes only if i==1

				// draw rect and add to overlay
				makeRectangle(X, coord[1], coord[2], coord[3]);
				Roi.setName(name);
				Overlay.addSelection(color);

				// unfortunately Overlay.setPosition(c, z, t) only works if c (or z?) > 1
				if (ch*sl == 1)		Overlay.setPosition(f);
				else				Overlay.setPosition(0, z, f);
			}
		}
	}
	run("Select None");

	// display and format overlay
	overlayFormatting();
}


function observationsDialog(CSV_lines, Results_Or_Header){
	out_order	= newArray();
	headers		= newArray();
	output		= newArray();
	Dialog.createNonBlocking("Score observations");

	if (Results_Or_Header == "results"){
		Dialog.setInsets(0, 0, 0);
		Dialog.addMessage("You are currently scoring cell# " + c + " (the double boxed cell).\n");
	}

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

	Dialog.setInsets(25, 20, 0);
	Dialog.addMessage("Remove this entry?\nNo results for this cell will be written to the results table\nand ROI boxes for this cell will be deleted");
	Dialog.addCheckbox("REMOVE THIS ENTRY?", 0);

	if (Results_Or_Header == "results") {

		// temporarily swap the overlay names with an extra box around the current cell
		xywhttzz2 = expandBox(xywhttzz, 2);
		makeOverlay(xywhttzz2, "temp_overlay", overlay_color2);
		Overlay.drawLabels(false);

		if (scoring != scoringOptions[0])	Dialog.show();

		for (i = 0; i < out_order.length; i++) {
			if (out_order[i] == "chk")	output[i] = Dialog.getCheckbox();
			if (out_order[i] == "str")	output[i] = Dialog.getString();
			if (out_order[i] == "num")	output[i] = Dialog.getNumber();
			if (out_order[i] == "opt")	output[i] = Dialog.getChoice();
		}
		if (Dialog.getCheckbox() )	return newArray();	// i.e. if delete the entry --> return empty array

		// replace overlay names and remove temp boxes
		Overlay.removeRois("temp_overlay");
		//Overlay.setLabelFontSize(8,"scale");
		Overlay.drawLabels(true);
		Overlay.show();

		return output;
	}
	else{
		return headers;
	}
}


function keepWaiting(){
	keep_waiting = 1;

	if (!isOpen("Waiting"))	exit("Session finished.\nYou can carry on later using the same experiment name and settings");

	if (nImages > 0) {	// check if all files were closed
		if (endsWith(getInfo("window.contents"), "SKIP") || endsWith(getInfo("window.contents"), "skip")){
			run("Select None");
			keep_waiting = 0;
		}

		if (box_progress == progressOptions[1]) { // draw only
			getRawStatistics(area);

			getCursorLoc(_, _, _, flags);	// flag=16 means left mouse button is down
			if (area < getWidth()*getHeight() && area > 0){		// checks if there is a selection
				if ( flags&16 == 0 ){							// checks whether left mouse button is down
					keep_waiting = 0;
				}
			}
		}

		else if (roiManager("count") > 0){	// draw + t
			keep_waiting = 0;
		}
	}
	else {	// if no files are open
		open();	// open new image
		run("Select None");
		overlay_file = overlay_file_prefix + getTitle() + ".zip";
		findPrevOverlay(overlay_file);
	}

	return keep_waiting;
}


function renameOldFiles(path){
	// extract date & time of last modification
	str = File.dateLastModified(path);
	A = split(str, " ");
	y = A[A.length-1];
	m = A[1];
	d = A[2];
	t = replace(A[3],":","");
	datetime = "_" + d + m + y + "_" + t;

	// save old table under new name
	prevResultsFile = saveloc + "_" + expname + "_Scoring" + datetime + ".csv";
	selectWindow(table);
	saveAs("Text", prevResultsFile);
	run("Close");

	// save old overlay files under new name
	flist = getFileList(saveloc);
	for (f = 0; f < flist.length; f++) {
		zipname = flist[f];
		if (startsWith(zipname, expname) && endsWith(zipname, "zip")) {
			newZipFilename = "_" + substring(zipname,0,lengthOf(zipname)-4) + datetime + ".zip";
			File.rename(saveloc + zipname, saveloc + newZipFilename);
		}
	}
}


function resaveTif(){
	info = getImageInfo();
	start = indexOf(info, "Path:") + 6;
	info = substring(info, start);
	end = indexOf(info, "\n");
	path = substring(info, 0, end);

	if (endsWith(path, ".tif") || endsWith(path, ".tiff") || endsWith(path, ".TIF") || endsWith(path, ".TIFF") || endsWith(path, ".Tif") || endsWith(path, ".Tiff") ) {
		save(path);
	}
}


function removeOverlays(index) {
	Overlay.removeRois("temp_overlay");
	Overlay.removeRois("c" + index);
	for (t = 0; t < nStages; t++) {
		Overlay.removeRois("c" + index + "_t" + t);
	}
	 Overlay.show
}


function expandBox(input, n){
	input[0] -= n;
	input[1] -= n;
	input[2] += 2*n;
	input[3] += 2*n;

	return input;

}


function overlayFormatting(){
	Overlay.show;
	Overlay.useNamesAsLabels(true);
	Overlay.drawLabels(true);
	Overlay.setLabelFontSize(8,"scale");
}


function findPrevOverlay(roi_path){
	if (File.exists(roi_path)){
		roiManager("Open", roi_path);
		run("From ROI Manager");
		roiManager("delete");
		overlayFormatting();
	}
}


function updateTable(S){
	for (i = 0; i < headers.length; i++) {
		Table.set(headers[i], S, results[i]);
		Table.update;
		Table.showRowNumbers(true);
	}
	if (Table.title != table)	Table.rename(Table.title, table);
}
