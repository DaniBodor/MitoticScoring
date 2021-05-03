notes_lines = 3;
surrounding_box = 8;	// in pixels


print("\\Clear");
mitotic_stages = newArray("NEBD", "Metaphase", "Anaphase onset", "Decondensation", "G1");
totStages = mitotic_stages.length;
stages_used = newArray(0);

// load previous defaults (if any)
default = newArray(totStages);
def_stages = getDirectory("macros") + "OrgaMovie_Scoring_defaultStages.txt";
if (File.exists(def_stages)){
	str = File.openAsString(def_stages);
	lines = split(str, ", ");
	if (lines.length == totStages)	default = lines; 
}

// open dialog to ask which stages to inlcude
Dialog.create("Mitotic stages");
	Dialog.setInsets(0, 15, 0)
	Dialog.addCheckboxGroup(totStages, 1, mitotic_stages,default);
//Dialog.show();
t=0;
	for (i = 0; i < totStages; i++) {
		default[i] = Dialog.getCheckbox();
		if (default[i])	{
			curr_header = "t" + t + " (" + mitotic_stages[i] + ")";
			stages_used = Array.concat(stages_used, curr_header);
			t++;
		}
	}

// save settings for next time
Array.print(default);
selectWindow("Log");
saveAs("Text", def_stages);
print("\\Clear");

nStages = stages_used.length;
Array.print(stages_used);

print(getTitle);



headers = newArray(
	"cell #",
	"NEBD time","Anaph onset time", "mitotic duration",
	"x0","y0","width","height",
	"skip","highlight",
	"lagger","bridge",
	"multipolar","# poles","micronucleated","# micronuclei","micronuclei before/after mitosis",
	"multinucleated","# nuclei","multinucleated before/after mitosis",
	"other","namely",
	"notes"
	);
header_line = arrayToString(headers,"\t");
print(header_line);

setTool("rectangle");

// loop per cell/event
for (c = 1; c > 0; c++){

	coordinates_array = newArray(0);
	for (t = 0; t < nStages; t++) {
		waitForUser("Draw a box around a cell at " + stages_used[t] + " of mitotic event.");
		current_xywht = getXYWHT();
		coordinates_array = Array.concat(coordinates_array, current_xywht);
	}
	Array.print(coordinates_array);
	coord_reorganized = reorganizeXYWHT(coordinates_array);
	Array.print(coord_reorganized);
vkldsngl


	events = GUI(notes_lines);
	
	
	x_min = minOf( xywht_NEBD[0] , xywht_AnaOn[0] );
	x_max = maxOf( xywht_NEBD[0] + xywht_NEBD[2] , xywht_AnaOn[0] + xywht_AnaOn[2] );
	y_min = minOf( xywht_NEBD[1] , xywht_AnaOn[1] );
	y_max = maxOf( xywht_NEBD[2] + xywht_NEBD[4] , xywht_AnaOn[2] + xywht_AnaOn[4] );
	w_tot = x_max - x_min;
	h_tot = y_max - y_min;

	coordinates = newArray(c,
		xywht_NEBD[4], xywht_AnaOn[4],interval,
		x_min,y_min,w_tot,h_tot);
	
	results = Array.concat(coordinates,events);
	results_line = arrayToString(results,"\t");
	print(results_line);
	

}





function GUI(nNotes){
	time_option = newArray("","before div","after div","both");
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
		lag,		bridge,
		multipole,	pole_number,
		micronuc,	micronuc_number,	micronuc_timing,
		multinuc,	multinuc_number,	multinuc_timing,
		other_obs,	other_type
		);
	
	GUI_result = Array.concat(GUI_result, notes);

	return GUI_result;
}


function getXYWHT(){
	getSelectionBounds(x, y, w, h);
	t = getSliceNumber();

	xywht = newArray(x, y, w, h, t);
	return xywht;
}

function reorganizeXYWHT(xywht_group){
	reorganized = newArray(0);
	for (j = 0; j < xywht_group.length/nStages; j++) {
		for (i = 0; i < xywht_group.length; i+=5) {
			reorganized = Array.concat(reorganized, xywht_group[i+j]);
		}
	}
	return reorganized;
}


function getMaxXYWH(xywht_group){
	xywht_group = reorganizeXYWHT(xywht_group);
	for (i = 1; i < xywht_group/5; i++) {
		
	}
}

function getMinOrMaxOfMultiple(array,MinOrMax){
	if		(MinOrMax == "min" || MinOrMax == "MIN" || MinOrMax == "Min" || MinOrMax == "-" || MinOrMax == "--") multipl = -1;
	else if (MinOrMax == "max" || MinOrMax == "MAX" || MinOrMax == "Max" || MinOrMax == "+" || MinOrMax == "++") multipl =  1;
	else if (MinOrMax == -1 || MinOrMax == 1)	multipl = MinOrMax;
	else	exit("MinOrMax set incorrectly, as: " + MinOrMax);
	
	return_value = array[0] * multipl;
	for (i = 1; i < array.length; i++) {
		current_test = array[i] * multipl;
		return_value = maxOf(current_test, return_value);
	}
	return_value = return_value * multipl;
	return return_value;
}



function arrayToString(A,splitter){
	string = "";
	for (i = 0; i < A.length; i++) {
		string = string + A[i] + splitter;
	}
	return string;
}
