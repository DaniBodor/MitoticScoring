defaults_file = getDirectory("macros") + "MitoticScoringDefaults" + File.separator + "Extractor.txt";
if (File.exists(defaults_file)) {
	defaults_str = File.openAsString(defaults_file);
	defaults = split(defaults_str, ", ");
}
else{
	File.makeDirectory(File.getParent(defaults_file));
	defaults = newArray("", "", 0, 10, 10, 0);
}

Dialog.create("Settings");
	Dialog.addFile	("Movie file",defaults[0]);
	Dialog.addString("Extract code", defaults[1], 33);
	Dialog.addNumber("Expand ROI", defaults[2], 0, 2, "pixels in each direction");
	Dialog.addNumber("Additional timepoints before", defaults[3], 0, 2, "frames");
	Dialog.addNumber("Additional timepoints after", defaults[4], 0, 2, "frames");
	Dialog.addNumber("Additional slices", defaults[5], 0, 2, "above and below");
Dialog.show();
	movie = Dialog.getString();
	xywhttzzc_string = Dialog.getString();
	expand  = Dialog.getNumber();
	tBefore = Dialog.getNumber();
	tAfter  = Dialog.getNumber();
	zExtra  = Dialog.getNumber();

newDefaults = String.join(newArray(movie,xywhttzzc_string,expand,tBefore,tAfter,zExtra));
//newDefaults = split(newDefaults, ", ");
File.saveString(newDefaults, defaults_file);

coordinates = adjustCoordinates(xywhttzzc_string);

run("Bio-Formats Importer", "open=" + movie + " autoscale color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT " +
	"c_begin=1 c_end=" + coordinates[8] + " c_step=1 "+
	"z_begin=" + coordinates[6] + " z_end=" + coordinates[7] + " z_step=1 " +
	"t_begin=" + coordinates[4] + " t_end=" + coordinates[5] + " t_step=1");
makeRectangle(coordinates[0], coordinates[1], coordinates[2], coordinates[3]);
run("Crop");

	

function adjustCoordinates(xywhttzzc){
	exitMessage = "incorrect extract code";
	C = split(xywhttzzc, "_");
	if (C.length != 9) exit(exitMessage);
	for (i = 0; i < 9; i++) {
		if (isNaN(parseInt(C[i]))) 	exit(exitMessage);
	}

	C[0] -= expand;	// x
	C[1] -= expand;	// y
	C[2] += (2*expand);	// w
	C[3] += (2*expand);	// h
	C[4] -= tBefore; // t_min
	C[5] += tAfter;	// t_max
	C[6] -= zExtra;	// z_min
	C[7] += zExtra;	// z_max
	C[8] += 0;	// nChannels
	
	return C;
}
