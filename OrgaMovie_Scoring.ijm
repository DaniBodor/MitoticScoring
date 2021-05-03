notes_lines = 3;
surrounding_box = 8;	// in pixels


print("\\Clear");
mitotic_stages = newArray("NEBD", "Metaphase", "Anaphase onset", "Decondensation", "G1");
nStages = mitotic_stages.length;
stages_used = newArray(0);

// load previous defaults (if any)
default = newArray(nStages);
def_stages = getDirectory("macros") + "OrgaMovie_Scoring_defaultStages.txt";
if (File.exists(def_stages)){
	str = File.openAsString(def_stages);
	lines = split(str, ", ");
	if (lines.length == nStages)	default = lines; 
}

// open dialog to ask which stages to inlcude
Dialog.create("Mitotic stages");
	Dialog.setInsets(0, 15, 0)
	Dialog.addCheckboxGroup(nStages, 1, mitotic_stages,default);
Dialog.show();
t=0;
	for (i = 0; i < nStages; i++) {
		default[i] = Dialog.getCheckbox();
		if (default[i])	{
			stages_used = Array.concat(stages_used, "t" + t + " (" + mitotic_stages[i] + ")");
			t++;
		}
	}

// save settings for next time
Array.print(default);
selectWindow("Log");
saveAs("Text", def_stages);
print("\\Clear");


Array.print(stages_used);
	



print(getTitle);
klbfjkgv



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
	
	waitForUser("Draw a box around a cell at NEBD of a mitotic event.");				xywht_NEBD = getXYWHT("NEBD");
	waitForUser("Draw a box around the same cell at anaphase onset.");					xywht_AnaOn = getXYWHT("AnaOn");
	//waitForUser("Draw a box around the same cell when decondensation is complete.");	xywht_Decond = getXYWHT("Decond");

	events = GUI(notes_lines);
	interval = xywht_AnaOn[4] - xywht_NEBD[4];
	
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


function getXYWHT(label){
	getSelectionBounds(x, y, w, h);
	t = getSliceNumber();

	xywht = newArray(x, y, w, h, t, label);
	return xywht;
}

function arrayToString(A,splitter){
	string = "";
	for (i = 0; i < A.length; i++) {
		string = string + A[i] + splitter;
	}
	return string;
}
