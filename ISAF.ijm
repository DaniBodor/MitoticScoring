// MITOTIC SCORING MACRO v1.4

// general stuff
requires("1.53g");
setJustification("center");
setFont("SansSerif", 9, "antialiased");
setOption("ExpandableArrays",true);

// close stuff before starting
waitwindowname = "Close this window to finish session";
if (isOpen(waitwindowname)){
	selectWindow(waitwindowname);
	run("Close");
}
if (Table.size > 0){
	T = Table.title;
	Table.reset(T);
}
roiManager("reset");

////  SETTINGS

// dialog option lists
colorArray = newArray("white","red","green","blue","cyan","magenta","yellow","orange","pink");
selectOptions = newArray("Draw only", "Draw + t");
scoringOptions = newArray("None", "Default", "Custom");

// fetch settings and move common ones into variable
fetchSettings();
InputSettings = List.getList;
nStages = parseInt(List.get("nStages"));
saveloc = List.get("saveloc")  + File.separator;


// load observation list 
	// search in default location or for default downloaded list.
obslist_dir = getDirectory("macros") + "_ObservationLists" + File.separator;
if (!File.exists(obslist_dir))	File.makeDirectory(obslist_dir);

obslist_path = obslist_dir + "ObservationList.csv";
scoring = List.get("scorechoice");
if (!File.exists(obslist_path)){
	assumed_obslist_path = getDir("file") + "DefaultObservationList.csv";
	if (File.exists(assumed_obslist_path) )		File.copy(assumed_obslist_path, obslist_path);
	else	scoring = scoringOptions[2];
}

// if non-default is used or default not found, ask for location
if (scoring == scoringOptions[2]){
	Dialog.create("Choose observation list");
	Dialog.addFile("Choose csv file for custom observation list", "");
	Dialog.addMessage("This list will be the default for future experiments " +
	"(so next time you can select 'default' to use this list)");
	Dialog.addMessage(	"Note that this window can pop up the first time you run the macro (or after moving macro files),\n" +
						"irrespective of choice for scoring Default / Custom / None");

	Dialog.show();
	new_obslist_path = Dialog.getString();
	if (!File.exists(new_obslist_path) || !endsWith(new_obslist_path, ".csv"))	exit("***ERROR:\nA non-existing or non-csv file was chosen as observation list");

	// store prev default obslist and copy new one to default
	if (obslist_path != new_obslist_path) {
		if (File.exists(obslist_path)){
			File.rename(obslist_path, obslist_path + "_" + getDatetime() + ".csv" );
			print("\\Update:previous scoring table backed up in "+File.getDirectory(obslist_path));
		}
		File.copy(new_obslist_path, obslist_path);
		obslist_path = new_obslist_path;
	}
}
obsCSV = split(File.openAsString(obslist_path), "\n");


// make headers string
init_headers = newArray("movie", "event#");
interv_headers = newArray();
end_headers = newArray();

for (i = 0; i < nStages; i++) {
	init_headers[i+2] = "t"+i;
	for (j = 0; j < i; j++) {
		interv_headers = Array.concat(interv_headers, "time_t" + i-j-1 + "-->t"+i);
	}
	t_header_suffix = "_XYWHTZ";
	end_headers[i] = "t"+i+t_header_suffix;
}
obs_headers = observationsDialog(obsCSV, "headers");
headers = Array.concat(init_headers, interv_headers, obs_headers, end_headers, "image_size", "extract_code");
headers_str = String.join(headers,"\t");


// define window and file names
expname = List.get("expname");
table = expname + "_Scoring.csv";
if (isOpen(table)){
	selectWindow(table);
	run("Close");
}
_table_ = "["+table+"]";
results_file = saveloc + table;
overlay_file_prefix = saveloc + expname + "_ROIs_";

// load progress
loadPreviousProgress(headers_str);
if	(Table.size > 0){
	prev_im =	Table.getString	("movie", Table.size-1);
	prev_c =	Table.get		("event#", Table.size-1);
}
else {
	prev_im = "no_prev_im";
	prev_c = 0;
}


// analyze individual events
setTool("rectangle");
im = getTitle();
for (c = prev_c+1; c > 0; c++){	// loop through cells

	coordinates_array = newArray();
	tpArray = newArray();				// array containing time frame for each stage
	intervalArray = newArray();			// array containing time interval between any combination of 2 stages	
	
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {
		run("Select None");
		// allow user to box mitotic cell

		// generate wait window information
		waitstring = "Draw box around cell at t" + tp;
		if (List.get("selectionoption") == selectOptions[1]){	// draw + t
			roiManager("reset");
			waitstring = waitstring + " and press 't' or add to ROI Manager";
		}
		for (prev = 0; prev < tp; prev++) {
			// print frame number for each previous tp
			if(isNaN(tpArray[prev]))	waitstring = waitstring + "\n\t t" + prev + " not defined";
			else						waitstring = waitstring + "\n\t t" + prev + " at frame " + tpArray[prev];
		}
		waitstring = waitstring + "\n\nIf you do not want to draw a box for this timepoint, type 'skip' on the line below.";
		waitstring = waitstring + "\nType 'hide' or 'show' to toggle whether previous ROIs are shown.";
		waitstring = waitstring + "\n\n";

		// generate wait window under image
		img = getTitle();
		makeWaitWindow();
		selectImage(img);

		// wait for drawing a box or skipping
		while (waitFunction())		wait(250);

		// get data from box
		if (selectionType == -1) {	// if no selection (i.e. skipped)
			x=NaN;y=NaN;w=NaN;h=NaN;f=NaN;z=NaN;
		}
		else {
			// get coordinates
			getSelectionBounds(x, y, w, h);
			if ( List.get("duplicatebox") )		x = x % (getWidth()/2);
			Stack.getPosition(_, z, f);

			// create overlay for current stage (t0, t1, etc)
			overlay_coord = newArray(x, y, w, h, f, f, z, z);
			overlay_name = "c" + c + "_t" + tp;
			makeOverlay(overlay_coord, overlay_name, List.get("maincolor"));
		}
		
		// close waitwindow
		selectWindow(waitwindowname);
		run("Close");
		run("Collect Garbage");

		// fix entry numbers, etc
		im = getTitle();
		im_size = d2s(getWidth(),0) + "x" + d2s(getHeight(),0);
		if (tp == 0 && im != prev_im ){
			if (Table.size == 0)	c = 1;
			else{
				imArray = Table.getColumn("movie");
				filtered = Array.filter(imArray, im);
				c = filtered.length + 1;
			}
			prev_im = im;
			Stack.getDimensions(_, _, ch, sl, fr);
			if (fr == 1 && ch*sl*fr>1){
				Stack.setDimensions(ch, fr, sl);
				Stack.getDimensions(_, _, ch, sl, fr);
				resaveTif();
			}
		}

		// store tp and interval data in arrays
		tpArray[tp] = f;
		for (j = 0; j < tp; j++)		intervalArray = Array.concat(intervalArray, (tpArray[tp] - tpArray[tp-j-1]) * List.get("timestep"));	// calculate frame difference * timestep for each comination

		// rearrange and store coordinates
		stage_coordinates = newArray(x, y, x+w, y+h, f, z);
		coordinates_array = Array.concat(coordinates_array, stage_coordinates);

		// find first existing timepoint and set slice accordingly
		if(List.get("jumptot0"))	jumpFunction();
	}
	run("Select None");

	// reorganize coordinates and create box overlay of cells already analyzed (only on relevant slices)
	nCoordinates = coordinates_array.length/nStages;
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhttzz = getFullSelectionBounds(reorganized_coord_array);
	if (nStages > 1)	makeOverlay(xywhttzz, "c" + c, List.get("minorcolor"));


	// run dialog window and extract information 
	observations = observationsDialog(obsCSV, "results");
	//Array.print(observations); // FOR TROUBLESHOOTING

	if (observations.length == 0){	// i.e. remove entry (effectively undo)
		removeOverlays(c);
		c--;
	}
	else {
		// generate results array with all inputs until tp coordinates
		results = Array.concat(im, c, tpArray, intervalArray, observations);

		// add coordinates for each stage and full image size
		for (i = 0; i < nStages; i++){
			curr_coord = Array.slice(coordinates_array, i*nCoordinates, (i+1)*nCoordinates);
			coord_string = String.join(curr_coord,"_");
			results = Array.concat(results, coord_string);
		}

		// add image size and extract code (i.e. extremes coordinates of all stages)
		xywhttzz_string = String.join(xywhttzz,"_");
		results = Array.concat(results, im_size, xywhttzz_string);

		writeToTable();
		// save overlay
		if (Overlay.size > 0){
			run("To ROI Manager");
			roiManager("Show All without labels");
			roiManager("deselect");
			overlay_file = overlay_file_prefix + getTitle() + ".zip";
			roiManager("save", overlay_file);
		}

		// save results progress
		selectWindow(table);
		saveAs("Text", results_file);
	}

	if( roiManager("count") > 0 )	run("From ROI Manager");
	close("ROI Manager");
}


////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////
////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////
////////////////////////////// CUSTOM FUNCTIONS ////////////////////////////////////

function reorganizeCoord(coord_group){
	reorganized = newArray();
	for (j = 0; j < nCoordinates; j++) {
		for (i = 0; i < coord_group.length; i += nCoordinates) {
			reorganized = Array.concat(reorganized, coord_group[i+j]);
		}
	}
	return reorganized;
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
		old_headers = split(Table.headings);

		// fix old table format for tpArray
		// (for rare case that someone was using the old version and now wants to keep scoring in the same file)
		for (h = 0; h < old_headers.length; h++) {
			oldName = old_headers[h];
			if (lengthOf(oldName) > 2) {
				if (startsWith(oldName, "t") && !isNaN(parseInt(substring(oldName, 1, 2))) && substring(oldName, 2, 3) == "_" && !endsWith (oldName, t_header_suffix) )  {
					// i.e. starts with t, then number, then underscore, but not already new format
					Table.renameColumn(oldName, oldName + t_header_suffix);
				}
			}
			Table.update;
		}
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
	findPrevOverlay();
}


function checkHeaders(new){
	//function obsolete
	selectWindow(table);
	old = Table.headings();
	if (Table.size() == 0)		run("Close");
	else if (old != new){
		// fix table order

	}
}


function jumpFunction(){
	// jumps to frame of t0 (or lowest t if t0 was skipped)
	for (q = 0; q < tp; q++) {
		jump_tp = tpArray[q];
		if (!isNaN(jump_tp)){
			Stack.setFrame(jump_tp);
			q = tp;
		}
	}
}


function makeOverlay(coord, name, color){
	// create rect at each frame
	// coord format: xywhttzz
	//Array.print(coord);
	for (f = coord[4]; f <= coord[5]; f++) {
		for (i = 0; i < List.get("duplicatebox")+1; i++) {	// 1 or 2 boxes, depending on List.get("duplicatebox")
			Stack.getDimensions(_, _, ch, sl, fr);
			zmin = maxOf(1, coord[6] - List.get("zspread"));
			zmax = minOf(sl, coord[7] + List.get("zspread"));
			for (z = zmin; z < zmax+1; z++) {

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
	// creates Dialog window to score observation
	out_order	= newArray();
	headers		= newArray();
	output		= newArray();
	Dialog.createNonBlocking("Score observations");

	if (Results_Or_Header == "results"){
		Dialog.setInsets(0, 0, 0);
		Dialog.addMessage("You are currently scoring the double boxed cell (event# " + c + ").\n");
	}

	for (l = 1; l < CSV_lines.length; l++) {
		currLine = split(CSV_lines[l],",");

		if (currLine [0] == "Group") {
			Dialog.setInsets(3, 0, 0);
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

	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Remove this entry?  No results or ROIs will be recorded for this cell.");
	Dialog.addCheckbox("REMOVE THIS ENTRY", 0);

	if (Results_Or_Header == "results") {

		// temporarily swap the overlay names with an extra box around the current cell
		expanded = expandBox(xywhttzz, 2);
		makeOverlay(expanded, "temp_overlay", List.get("minorcolor"));
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
		if (Overlay.size > 0){
			Overlay.removeRois("temp_overlay");
			Overlay.drawLabels(true);
			Overlay.show();
		}

		return output;
	}
	else {
		return headers;
	}
}


function waitFunction(){
	keep_waiting = 1;

	if (!isOpen(waitwindowname))	exit("Session finished.\nYou can carry on later using the same experiment name and settings");

	if (nImages > 0) {	// check if all files were closed
		winContent = getInfo("window.contents");
		winContent = split(winContent);
		winContent = winContent[winContent.length-1].toLowerCase;

		if (indexOf(winContent, "hide") >= 0 ) {
			run("Hide Overlay");
		}
		else if (indexOf(winContent, "show") >= 0 ) {
			run("Show Overlay");
		}

		
		if (indexOf(winContent, "skip") >= 0 ) {
			run("Select None");
			keep_waiting = 0;
		}

		else if (List.get("selectionoption") == selectOptions[0]) { // draw only
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
		if (List.get("trackmate_integration") == 1)		exit("Session finished.\nYou can carry on later using the same experiment name and settings");
		else {
			open();	// open new image
			run("Select None");
			findPrevOverlay();
		}
	}

	return keep_waiting;
}


function renameOldFiles(path){
	// function obsolete
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
	if (Overlay.size > 0){
		Overlay.removeRois("temp_overlay");
		Overlay.removeRois("c" + index);
		for (t = 0; t < nStages; t++) {
			Overlay.removeRois("c" + index + "_t" + t);
		}
		run("Select None");
		Overlay.show
	}
}


function expandBox(input, n){
	output = newArray();
	output[0] = input[0] - n;
	output[1] = input[1] - n;
	output[2] = input[2] + 2*n;
	output[3] = input[3] + 2*n;

	for (i = 4; i < input.length; i++) output[i] = input[i];
	
	return output;

}


function overlayFormatting(){
	if (Overlay.size > 0){
		Overlay.show;
		Overlay.useNamesAsLabels(true);
		Overlay.drawLabels(true);
		Overlay.setLabelFontSize(8,"scale");
	}
}


function findPrevOverlay(){
	// opens and displays overlays from previous session
	if (List.get("trackmate_integration") == 0){
		if (nImages > 0)	Overlay.remove;
		else				open();
		
		roi_path = overlay_file_prefix + getTitle() + ".zip";
		if (File.exists(roi_path)){
			roiManager("Open", roi_path);
			run("From ROI Manager");
			roiManager("delete");
			overlayFormatting();
		}
	}
	else {	// run on trackmate file
		if (nImages == 0)	run("Load a TrackMate file");
		roi_path = overlay_file_prefix + getTitle() + ".zip";
		
		if (File.exists(roi_path)){
			run("To ROI Manager");
			while (roiManager("count") > 2) {
				roiManager("select", 2);
				roiManager("delete");
			}
			roiManager("Open", roi_path);
			roiManager("select", newArray(2,3));
			roiManager("delete");
			run("From ROI Manager");
			roiManager("delete");
			overlayFormatting();
		}
	}
}


function writeToTable(){
	nRows = Table.size;
	
	for (i = 0; i < headers.length; i++)	Table.set(headers[i], nRows, results[i]);
	if (Table.title != table)	Table.rename(Table.title, table);
	Table.showRowNumbers(true);
	Table.update;
}


function getDatetime(){
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);

	y = d2s(year,0);
	mo = IJ.pad(month+1,2);
	d = IJ.pad(dayOfMonth,2);
	date = y + mo + d;

	h = IJ.pad(hour,2);
	min = IJ.pad(minute,2);
	time = h + min;

	return "d" + date + "_t" + time;
}



function makeWaitWindow(){
	/*
	 * this is an overly complicated function
	 * to find the best location for the wait window
	 * ###### also: it doesn't always work for some reason, might depend on screen size or resolution??
	 */
	
	//define waitwindow size
	waitwindow_w = 80;
	waitwindow_h = 8;
	
	// get screen & image size
	scr_w = screenWidth;
	scr_h = screenHeight;
	getLocationAndSize(im_x, im_y, im_w, im_h);
	print_coords = false;
	if (print_coords){ // for testing offsets
		print("screen size", scr_w,scr_h);
		print("image loc", im_x,im_y);
		print("image size", im_w,im_h);
	}	
	
	// find potential location for waitwindow
	x_offset = 600;
	y_offset = 200;
	fitUnder = false; fitLeft = false; fitAbove=false; fitRight = false;
	if (im_y + im_h < scr_h - y_offset)		fitUnder = true;
	if (im_x + im_w < scr_w - x_offset)		fitLeft  = true;
	if (im_y > y_offset)					fitAbove = true;
	if (im_x > x_offset)					fitRight = true;
	
	// open waitwindow
	run("Text Window...", "name=[&waitwindowname] width=&waitwindow_w height=&waitwindow_h");
	print("[" + waitwindowname + "]", waitstring);
	
	// place waitwindow
	// in this order of preference: below, right, above, left
	selectWindow(waitwindowname);
	if (fitUnder){
		if (scr_w - im_x < x_offset) setLocation(im_x + im_w - x_offset, 	im_y + im_h);
		else 						 setLocation(im_x, 						im_y + im_h);
	}
	
	else if (fitLeft)				 setLocation(im_x + im_w , 				im_y/2 + im_h/2);
	
	else if (fitAbove){
		if (scr_w - im_x < x_offset) setLocation(im_x + im_w - x_offset, 	im_y - y_offset);
		else 						 setLocation(im_x, 						im_y - y_offset);
	}

	else if (fitRight)				 setLocation(im_x - x_offset , 			im_y/2 + im_h/2);
}


function fetchSettings(){
	// when adding any new settings to the dialog, make sure to add a line in 3 places:
	// - under Dialog.create --- to ask for the new setting from GUI
	// - under Dialog.show --- to fetch the new setting from input
	// - under default_settings() function --- to initiate a default setting
	
	// load default settings
	default_settings();
	List.toArrays(def_keys, def_values);

	// load previous settings
	settings_dir = getDirectory("macros") + "settings" + File.separator;
	if(!File.exists(settings_dir))	File.makeDirectory(settings_dir);
	settings_file = settings_dir + "ScoringMacro.txt";
	if(File.exists(settings_file)){
		settings_string = File.openAsString(settings_file);
		List.setList(settings_string);
		
		// in case any default settings are missing from saved file, add these back
			// e.g. due to new settings added in updates or due to corruption of the settings file
		List.toArrays(load_keys, load_values);
		for (i = 0; i < def_keys.length; i++) {
			filtered = Array.filter(load_keys,def_keys[i]);	// either empty array or array of length 1
			present = lengthOf(filtered);	// should output 0 or 1 --> can be used as boolean
			if ( !present )		List.set(def_keys[i], def_values[i]);
		}
	}

	// dialog layout
	colw = 8;
	title_fontsize = 12;
	github = "https://github.com/DaniBodor/MitoticScoring#setup";

	// open dialog
	Dialog.createNonBlocking("Scoring Macro");
		Dialog.addHelp(github);
		
		Dialog.setInsets(10, 0, 0);
		Dialog.addMessage("GENERAL SETTINGS",title_fontsize);
		Dialog.addDirectory("Save Location", List.get("saveloc"));
		Dialog.addString("Experiment Name", List.get("expname"), colw-2);
		Dialog.addNumber("Time step", List.get("timestep"), 0, colw, "");
		
		Dialog.setInsets(20, 0, 0);
		Dialog.addMessage("SCORING SETTINGS",title_fontsize);
		Dialog.addChoice("Score observations",  scoringOptions, List.get("scorechoice") );
		Dialog.addChoice("Define ROI by", selectOptions, List.get("selectionoption"));
		Dialog.addNumber("ROIs per event", List.get("nStages"), 0, colw, "");
		Dialog.addToSameRow();
		//Dialog.setInsets(0, 135, 0);
		Dialog.addCheckbox("Always jump to t0", List.get("jumptot0") );

		Dialog.setInsets(20, 0, 0);
		Dialog.addMessage("VISUAL SETTINGS",title_fontsize);
		Dialog.addChoice("ROI color - main", colorArray, List.get("maincolor"));
		Dialog.addChoice("ROI color - minor", colorArray, List.get("minorcolor"));
		Dialog.addNumber("Z-spread (+/-)", List.get("zspread"), 0, colw, "");
		Dialog.addCheckbox("Show intermediate timepoints", List.get("intermediateboxes"));
		Dialog.addCheckbox("Run on TrackMate files", List.get("trackmate_integration"));
		
		Dialog.setInsets(20, 0, 0);
		Dialog.addMessage("For OrgaMovies");
		Dialog.addCheckbox("Duplicate left and right?", List.get("duplicatebox"));

	Dialog.show();
		// move settings from dialog window into a key/value list
		// general settings
		saveloc_input = Dialog.getString();
			// reading save location is a bit buggy, this fixes it
			saveloc_parent = File.getDirectory(saveloc_input);
			saveloc_folder = File.getName(saveloc_input);
			List.set("saveloc", saveloc_parent + saveloc_folder);
		List.set("expname", Dialog.getString());
		List.set("timestep", Dialog.getNumber());
			if (List.get("timestep") == 0)	List.set("timestep", 1);
		// scoring settings		
		List.set("scorechoice", Dialog.getChoice());
		List.set("selectionoption", Dialog.getChoice());
		List.set("nStages", Dialog.getNumber());
			if (List.get("nStages") == 0)	List.set("nStages", 1);
		List.set("jumptot0", Dialog.getCheckbox());
		//visual settings
		List.set("maincolor", Dialog.getChoice());
		List.set("minorcolor", Dialog.getChoice());
		List.set("zspread", Dialog.getNumber());
		List.set("intermediateboxes", Dialog.getCheckbox());
		List.set("trackmate_integration", Dialog.getCheckbox());
		//orgamovies
		List.set("duplicatebox", Dialog.getCheckbox());

	// save settings
	InputSettings = List.getList;
		// custom list becomes new default (change only recorded for export string, the setting itself is not changed)
	InputSettings = replace(InputSettings,"scorechoice="+scoringOptions[2],"scorechoice="+scoringOptions[1]);
	File.saveString(InputSettings, settings_file);

	// check if save location is a valid path
	if (!File.isDirectory(List.get("saveloc")))		File.makeDirectory(List.get("saveloc"));	// I don't think this still works. dir needs to exist before running macro
	if (!File.isDirectory(List.get("saveloc")))		exit("Chosen save location does not exist; please choose valid directory");
}


function default_settings(){
	List.clear();
	// general settings
	List.set("saveloc", getDirectory("image"));
	List.set("expname", "");
	List.set("timestep", 1);
	// scoring settings		
	List.set("selectionoption", selectOptions[0]);
	List.set("nStages", 2);
	List.set("jumptot0", 0);
	List.set("scorechoice", scoringOptions[1]);
	//visual settings
	List.set("maincolor", "red");
	List.set("minorcolor", "white");
	List.set("zspread", 0);
	List.set("intermediateboxes", 1);
	List.set("trackmate_integration", 0);
	//for orgamovies
	List.set("duplicatebox", 0);
}
