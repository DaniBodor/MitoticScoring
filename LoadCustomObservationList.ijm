requires("1.53f");
OS = getInfo("os.name")
//path = File.openDialog("Dialog list file");
path = "C:\\Users\\dani\\Documents\\MyCodes\\MitoticScoring\\ObservationList.csv";
string = File.openAsString(path);
lines = split(string,"\n");


out_order = newArray();
headers = newArray();
Dialog.create("Customized observations list");
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Record your observations below");
for (l = 1; l < lines.length; l++) {
	currLine = split(lines[l],",");
	
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
			Dialog.addString(currLine[1], "");
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
			headers = Array.concat(headers, "#");
			Dialog.addToSameRow();
			//Dialog.setInsets(-20,120,0);
			Dialog.addString("#", "");
			out_order = Array.concat(out_order,"str");
		}
		if (currLine [3]){	// Add_Text
			headers = Array.concat(headers, curr_header+"_note");
			Dialog.addToSameRow();
			//Dialog.setInsets(-20,120,0);
			Dialog.addString("", "");
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
Dialog.show();
output = newArray();
for (i = 0; i < out_order.length; i++) {
	if (out_order[i] == "chk")	output = Array.concat(output, Dialog.getCheckbox() );
	if (out_order[i] == "str")	output = Array.concat(output, Dialog.getString()   );
	if (out_order[i] == "num")	output = Array.concat(output, Dialog.getNumber()   );
	if (out_order[i] == "opt")	output = Array.concat(output, Dialog.getChoice()   );

//	if output[i] = ""
}

Table.create("Table");
print("[Table]", "\\Headings:" + String.join(headers,"\t"));
print("[Table]", String.join(output,"\t"));