//path = File.openDialog("Dialog list file");
path = "C:\\Users\\dani\\Documents\\MyCodes\\MitoticScoring\\ObservationList.csv";
string = File.openAsString(path);
lines = split(string,"\n");



Dialog.create("Customized observations list");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Record your observations below");
for (l = 1; l < lines.length; l++) {
	//print(lines[l]);
	currLine = split(lines[l],",");
	
	if (currLine [0] == "Group") {
		Dialog.setInsets(10, 0, 0);
		Dialog.addMessage(currLine[1]);
	}
	
	else {
		Dialog.setInsets(0,10,0);
		choices =  Array.slice(currLine, 5, currLine.length);
		for (i = 0; i < choices.length; i++) choices[i] = replace(choices[i], "\"", "");

		// add main
		if (currLine [0] == "Checkbox")	Dialog.addCheckbox(currLine[1], 0);
		if (currLine [0] == "Text")		Dialog.addString(currLine[1], " ");
		if (currLine [0] == "Number")	Dialog.addNumber(currLine[1], " ");
		if (currLine [0] == "File")		Dialog.addFile(currLine[1], " ");
		if (currLine [0] == "List")		Dialog.addChoice(currLine[1], choices);

		// add extras
		if (currLine [2]){	// Add_#
			Dialog.addToSameRow();
			Dialog.addString("#", "");
		}
		if (currLine [3]){	// Add_Text
			Dialog.addToSameRow();
			Dialog.addString("", "");
		}
		if (currLine [4]){	// Add_List
			Dialog.addToSameRow();
			Dialog.addChoice("", choices);
		}
	}
}

Dialog.show();





