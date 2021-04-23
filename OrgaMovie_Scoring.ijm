print("\\Clear");
notes_lines = 3;

A = getTitle();



setTool("rectangle");
waitForUser("Draw a box around a cell at NEBD of a mitotic event.");				coord_NEBD = getXYT("NEBD");
waitForUser("Draw a box around the same cell at anaphase onset.");					coord_AnaOn = getXYT("AnaOn");
waitForUser("Draw a box around the same cell when decondensation is complete.");	coord_Decond = getXYT("Decond");
observations = GUI(notes_lines);

for(i = 0; i < observations.length; i++){
	print(i, observations[i]);
}




function GUI(nNotes){
	time_option = newArray("","before div","after div","both");
	skip_option = newArray("NO","YES");
	notes = newArray(nNotes);
	
	Dialog.createNonBlocking("Observations checklist");
		Dialog.addMessage("Do you want to skip analysis for this cell?");
		Dialog.addChoice("SKIP THIS CELL?", skip_option);
		Dialog.addMessage("If not, register observations for this mitosis below:");
		
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
		skip,
		lag,
		bridge,
		multipole,	pole_number,
		micronuc,	micronuc_number,	micronuc_timing,
		multinuc,	multinuc_number,	multinuc_timing,
		other_obs,	other_type,
		"");
	
	GUI_result = Array.slice(GUI_result, 0, GUI_result.length-1);
	GUI_result = Array.concat(GUI_result, notes);

	return GUI_result;
}


function getXYT(label){
	getSelectionBounds(x, y, w, h);
	t = getSliceNumber();

	xywht = newArray(x, y, w, h, t, label);
	return xywht;
}

