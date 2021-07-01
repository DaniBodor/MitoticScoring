// load previous settings as default
defaults_file = getDirectory("macros") + "MitoticScoringDefaults" + File.separator + "Extractor.txt";
defaults = newArray("", "", 0, 10, 10, 0, 0, 0);

if (File.exists(defaults_file)) {
	defaults_str = File.openAsString(defaults_file);
	loaded = split(defaults_str, ",");
	for (i = 0; i < loaded.length; i++) {
		loaded[i] = loaded[i].trim();
	}
	if (loaded.length == defaults.length)	defaults = loaded;
}
else 	File.makeDirectory(File.getParent(defaults_file));


// open dialog to ask for extraction
Dialog.create("Settings");
	Dialog.addHelp("https://github.com/DaniBodor/MitoticScoring#subimage-extractor");
	Dialog.addFile	("Movie file",defaults[0]);
	Dialog.addString("Extract code", defaults[1], 33);
	Dialog.setInsets(20, 20, 0);
	Dialog.addMessage("Change extraction dimensions");
	Dialog.addNumber("Expand box", defaults[2], 0, 2, "pixels in each direction");
	Dialog.addNumber("Additional timepoints before", defaults[3], 0, 2, "frames");
	Dialog.addNumber("Additional timepoints after", defaults[4], 0, 2, "frames");
	Dialog.addNumber("Additional slices", defaults[5], 0, 2, "above and below");
	Dialog.addCheckbox("Right side of OrgaMovie (DOESN'T CURRENTLY WORK)", defaults[6])
	Dialog.setInsets(30, 20, 0);
	Dialog.addMessage("For troubleshooting");
	Dialog.setInsets(0, 5, 0)
	Dialog.addCheckbox("Swap T and Z", defaults[7]);
Dialog.show();
	movie = Dialog.getString();
	xywhttzz_string = Dialog.getString();
	expand  = Dialog.getNumber();
	tBefore = Dialog.getNumber();
	tAfter  = Dialog.getNumber();
	zExtra  = Dialog.getNumber();
	rightside = Dialog.getCheckbox();
	swapTZ = Dialog.getCheckbox();

if (!File.exists(movie)) exit("file not found\n"+movie);

// save settings as next default
newDefaults = String.join(newArray(movie, xywhttzz_string, expand, tBefore, tAfter, zExtra, rightside, swapTZ) );
File.saveString(newDefaults, defaults_file);

// open section of file according to coordinates
// (avoids opening of huge organoid movie if only few frames are required)
coordinates = adjustCoordinates(xywhttzz_string);
run("Bio-Formats Importer", "open=[" + movie + "] autoscale color_mode=Default crop rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT " +
	"z_begin=" + coordinates[6] + " z_end=" + coordinates[7] + " z_step=1 " +
	"t_begin=" + coordinates[4] + " t_end=" + coordinates[5] + " t_step=1 " +
	"x_coordinate_1=" + coordinates[0] + " y_coordinate_1=" + coordinates[1] + " width_1=" + coordinates[2] + " height_1=" + coordinates[3]);

Stack.getDimensions(_, _, ch, _, _);
if (ch>1)	run("Channels Tool...");
resetMinAndMax;



function adjustCoordinates(xywhttzz){
	/*
	 * this function is used to adjust the extract-code coordinates
	 * according to the input settings from the dialog
	 */
	
	// check extract code
	exitMessage = "error in extract code";
	C = split(xywhttzz, "_");
	if (C.length != 8) exit(exitMessage);
	for (i = 0; i < 8; i++) {
		if (isNaN(parseInt(C[i]))) 	exit(exitMessage);
	}

	// in case extract code got mixed up
	if (swapTZ){
		 t_min = C[6];
		 t_max = C[7];
		 C[6] = C[4];
		 C[7] = C[5];
		 C[4] = t_min;
		 C[5] = t_max;
	}


	// fix avi opening as if Z-stack instead of time-lapse
	if (endsWith(movie, ".avi") || endsWith(movie, ".Avi") || endsWith(movie, ".AVI")){
		C[4] = C[6];
		C[5] = C[7];
		C[6] = 1;
		C[7] = 1;
	}

	// adjust coordinates according to settings
	C[0] -= expand;	// x
	C[1] -= expand;	// y
	C[2] += (2*expand);	// w
	C[3] += (2*expand);	// h
	C[4] -= tBefore; // t_min
	C[5] += tAfter;	// t_max
	C[6] -= zExtra;	// z_min
	C[7] += zExtra;	// z_max

	// adjust if right hand side of OrgaMovie is chosen
	//C[0] += rightside*getWidth()/2;
	
	return C;
}
