notes_lines = 3;
surrounding_box = 8;	// in pixels



//print("\\Clear");
Overlay.remove;

mitotic_stages = newArray("NEBD", "Metaphase", "Anaphase_onset", "Decondensation", "G1");
totStages = mitotic_stages.length;
stages_used = newArray(0);

// load previous defaults (if any)
default = newArray(totStages);
def_stages = getDirectory("macros") + "OrgaMovie_Scoring_defaultStages.txt";
if (File.exists(def_stages)){
	str = File.openAsString(def_stages);
	lines = split(str, "\n");
	lines = Array.slice(lines,1,lines.length);
	if (lines.length == totStages)	default = lines;
}

// open dialog to ask which stages to inlcude
t=0;
Dialog.create("Mitotic stages");
	Dialog.setInsets(0, 15, 0)
	Dialog.addCheckboxGroup(totStages, 1, mitotic_stages,default);
//Dialog.show();
for (i = 0; i < totStages; i++) {
	default[i] = Dialog.getCheckbox();
	if (default[i])	{
		curr_header = "t" + t + "_" + mitotic_stages[i];
		stages_used = Array.concat(stages_used, curr_header);
		t++;
	}
}
// save settings for next time

Array.show(default);
selectWindow("default");
saveAs("Text", def_stages);
run("Close");
nStages = stages_used.length;
//Array.print(stages_used);


// create and print headers for output
print(getTitle);

headers = newArray("cell#");	// first entry of headers
for (s = 1; s < nStages; s++) {		// then add the individual intervals
	t_header = "time_t" + s-1 + "-->t" + s;
	headers = Array.concat(headers,t_header);
}

headers = Array.concat(headers,newArray(	// then add the possible events
	"skip","highlight",
	"lagger","bridge","misaligned",
	"multipolar","#_poles","micronucleated","#_micronuclei","micronuclei_before/after_mitosis",
	"multinucleated","#_nuclei","multinucleated_before/after_mitosis",
	"other","namely"));

for (nl = 0; nl < notes_lines; nl++) headers = Array.concat(headers,"notes");	// then add lines for notes
headers = Array.concat(headers,stages_used);		// then coordinates of each mitotic stage
headers = Array.concat(headers, "extract_code");	// then a code to allow for quick extraction (Gaby request)

Array.print(headers);


// analyze individual events
setTool("rectangle");
for (c = 1; c > 0; c++){	// loop through cells

	coordinates_array = newArray(0);
	// for each time point included, pause to allow user to define coordinates
	for (tp = 0; tp < nStages; tp++) {
		getRawStatistics(area);
		waitForUser("Draw a box around a cell at " + stages_used[tp] + " of mitotic event.");
		current_coord = getCoordinates();
		coordinates_array = Array.concat(coordinates_array, current_coord);

		// create overlay of cells already analyzed
		setColor("red");
		x_mid = (current_coord[0] + current_coord[2])/2;
		Overlay.drawString("t"+tp, x_mid-6, current_coord[1]-1);
		Overlay.setPosition(getSliceNumber());
	}
	run("Select None");

	// extract coordinates for output
	reorganized_coord_array = reorganizeCoord(coordinates_array);
	xywhtt = getFullSelectionBounds(reorganized_coord_array);
	
	intervals = newArray(nStages-1);
	for (i = 0; i < intervals.length; i++) {
		intervals[i] = reorganized_coord_array[4*nStages+i+1] - reorganized_coord_array[4*nStages+i];
	}
	
	setColor("white");
	for (t = xywhtt[4]; t <= xywhtt[5]; t++) {
		Overlay.drawRect(xywhtt[0], xywhtt[1], xywhtt[2], xywhtt[3]);
		Overlay.setPosition(t);
		Overlay.add;
	}
	Overlay.show;
	
	// run function to determine mitotic events
	events = GUI(notes_lines);

	// create and print results line
	results = Array.concat(c,intervals);
	results = Array.concat(results,events);
	
	for (i = 0; i < nStages; i++){
		curr_coord = Array.slice(coordinates_array, i*5, i*5+5);
		coord_string = arrayToString(curr_coord,"_");
		results = Array.concat(results,coord_string);
	}
	xywhtt_string = arrayToString(xywhtt,"_");
	results = Array.concat(results,xywhtt_string);

	Array.print(results);
}





function GUI(nNotes){
	time_option = newArray("","before_div","after_div","both");
	no_yes = newArray("NO","YES");
	notes = newArray(nNotes);
	
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
		Dialog.addMessage("");
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
		for (i = 0; i < nNotes; i++) 	notes[i] = Dialog.getString;

	GUI_result = newArray(
		skip,		highlighted,
		lag,		bridge,				misaligned,
		multipole,	pole_number,
		micronuc,	micronuc_number,	micronuc_timing,
		multinuc,	multinuc_number,	multinuc_timing,
		other_obs,	other_type
		);
	
	GUI_result = Array.concat(GUI_result, notes);
	for (r = 0; r < GUI_result.length; r++) {
		if (GUI_result[r] == "")	GUI_result[r] = "_";
	}

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
