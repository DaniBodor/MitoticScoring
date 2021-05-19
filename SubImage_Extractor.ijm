

xywhttzzc_string = "113_1_82_53_234_249_1_1_1";

movie = "C:\\Users\\dani\\Documents\\MyCodes\\MitoticScoring\\test_data\\Organoid_projection.tif";

coordinates = split(xywhttzzc_string, "_")



//	run("Bio-Formats Importer", "open=" + movie + " autoscale color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT t_begin=" + coordinates[4] +" t_end=" + coordinates[5] +" t_step=1");
run("Bio-Formats Importer", "open=" + movie + " autoscale color_mode=Default rois_import=[ROI manager] specify_range view=Hyperstack stack_order=XYCZT " +
	"c_begin=1 c_end=" + coordinates[8] + " c_step=1 "+
	"z_begin=" + coordinates[6] + " z_end=" + coordinates[7] + " z_step=1 " +
	"t_begin=" + coordinates[4] + " t_end=" + coordinates[5] + " t_step=1");
makeRectangle(coordinates[0], coordinates[1], coordinates[2], coordinates[3]);
run("Crop");

	




