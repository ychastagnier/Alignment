
requires("1.52s")

var scale = 0.25;
var sigmaGauss = 6;
var radiusMedian = 3;
var marginAlign = 0.15;
var marginCorrel = 0.15;
var extractStep = 20;
var methods = newArray("translation", "rigidBody");
var method = methods[0];
var alignRefs = newArray("sequentially.", "on computed slice.", "on specified slice.");
var alignRef = alignRefs[1];
var sliceRef = 1;
var overwriteResults = false;
var alignSaveStacks = false;

var buttonID = 0;
var stackID = 0;
var slice = -1;
var dx = newArray(1);
var ox = 0;
var dy = newArray(1);
var oy = 0;
var dtheta = newArray(1);
var otheta = 0;
var correl = newArray(1);
var ocorrel = 0;
var files = newArray(0);
var currfile = 0;
var verbose = false;

macro "Align currently selected stack Action Tool - B03 C059 T040dS T740di Ta40dn T0f0dg T8f0dl Tbf0de" {button1();}
macro "Compute stacks intra shifts of a folder Action Tool - B03 C059 T240dI T640dn T0f0dt T5f0dr Taf0da" {button2();}
macro "Compute stacks inter shifts of a folder Action Tool - B03 C059 T240dI T640dn T0f0dt T5f0de Tdf0dr" {button3();}
macro "Open stack and apply shifts Action Tool - B03 C059 T040dA T940dp T0f0dp T8f0dl Tcf0dy" {button4();}
macro "Apply shifts and save stacks Action Tool - B03 C059 T040dA T940dp T0f0dp T8f0dl Tcf0dy" {button5();}
//macro "Compute and save correlations Action Tool - B03 C059 T040dC T840do Tf40dr T2f0dr T7f0de Tef0dl" {button6();}


function button1() {
	if (isStack()) {
		stackID = getImageID();
	} else {
		showMessage("No image open or current image is not a stack");
		return;
	}
	buttonID = 1;
	updateParms();
	ox = 0;
	oy = 0;
	otheta = 0;
	ocorrel = 0;
	setBatchMode(true);
	verbose = false;
	computeCurrentStackShifts(stackID);
	applyShiftsOnStack(stackID);
	measureCorrel(stackID);
	print(slice+", "+ox+", "+oy+", "+otheta+", "+ocorrel);
	Array.print(dx);
	Array.print(dy);
	Array.print(dtheta);
	Array.print(correl);
	plotShifts();
	setBatchMode("exit and display");
}

function button2() {
	buttonID = 2;
	updateParms();
	message = "Choose directory containing stacks for which intra shifts must be calculated";
	showStatus(message);
	dir = getDirectory(message);
	files = newArray(0);
	files = getTifFiles(dir, files);
	ox = 0;
	oy = 0;
	otheta = 0;
	ocorrel = 0;
	initializeLog();
	slicesAligned = 0;
	startTime = getTime();
	setBatchMode(true);
	verbose = true;
	for (i = 0; i < files.length; i++) {
		currfile = i;
		shiftFile = getShiftsFile(files[i]);
		if (overwriteResults || !File.exists(shiftFile)) {
			if (alignSaveStacks) {
				run("Bio-Formats Importer", "open=["+files[i]+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
			} else {
				run("Bio-Formats Importer", "open=["+files[i]+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
			}
			stackID = getImageID();
			slicesAligned = slicesAligned + nSlices;
			computeCurrentStackShifts(stackID);
			if (alignSaveStacks) {
				applyShiftsOnStack(stackID);
				measureCorrel(stackID);
				alignFile = getAlignFile(files[i]);
				saveAs("tiff", alignFile);
			}
			saveShifts(shiftFile);
			close();
		}
		print("\\Update1:"+(i+1)+"/"+files.length+" stack(s) aligned, "+slicesAligned+" slice(s) aligned in "+(getTime()-startTime)/1000+"s");
	}
	print("\\Update0:Intra stack alignment done.");
	print("\\Update2:");
	showStatus("Intra stack alignment done.");
	setBatchMode(false);
}

function button3() {
	buttonID = 3;
	updateParms();
	message = "Choose directory containing stacks for which inter shifts must be calculated";
	showStatus(message);
	dir = getDirectory(message);
	files = newArray(0);
	files = getTifFiles(dir, files);
	ox = 0;
	oy = 0;
	otheta = 0;
	ocorrel = 0;
	setBatchMode(true);
	verbose = false;
	slicesID = newArray(files.length);
	for (i = 0; i < files.length; i++) {
		currfile = i;
		shiftFile = getShiftsFile(files[i]);
		if (File.exists(shiftFile)) {
			shiftsstr = split(File.openAsString(shiftFile), ",");
			slicesID[i] = parseInt(shiftsstr[0]);
			run("Bio-Formats Importer", "open=["+files[i]+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT use_virtual_stack");
			rename("toClose");
			setSlice(slicesID[i]);
			run("Duplicate...", "title=toAdd-"+i);
			close("toClose");
		}
	}
	run("Images to Stack", "name=AllStacks title=toAdd-");
	stackID = getImageID();
	computeCurrentStackShifts(stackID);
	applyShiftsOnStack(stackID);
	measureCorrel(stackID);
	index = 0;
	for (i = 0; i < files.length; i++) {
		shiftFile = getShiftsFile(files[i]);
		if (File.exists(shiftFile)) {
			lines = split(File.openAsString(shiftFile),"\n");
			f = File.open(shiftFile);
			print(f, slicesID[i]+", "+dx[index]+", "+dy[index]+", "+dtheta[index]+", "+correl[index]);
			for (l = 1; l < lines.length; l++) {
				print(f, lines[l]);
			}
			File.close(f);
			setSlice(index+1);
			setMetadata("Label", slicesID[i]+" "+File.getName(File.getParent(files[i]))+File.separator+File.getName(files[i]));
			index++;
		}
	}
	showStatus("Inter alignments done.");
	setBatchMode(false);
}

function button4() {
	buttonID = 4;
	verbose = false;
	path = File.openDialog("Select a stack to open and align");
	shiftPath = getShiftsFile(path);
	if (!File.exists(shiftPath)) {
		showMessage("Shift file doesn't exist:\n"+shiftPath+"\nImage opening canceled.");
		return;
	}
	loadShifts(shiftPath);
	open(path);
	stackID = getImageID();
	applyShiftsOnStack(stackID);
	showStatus("Done.");
}

function button5() {
	buttonID = 5;
	Dialog.create("Parameters");
	Dialog.addCheckbox("Overwrite results?", overwriteResults);
	Dialog.show();
	overwriteResults = Dialog.getCheckbox();
	verbose = true;
	message = "Choose directory containing stacks to align and save";
	showStatus(message);
	dir = getDirectory(message);
	files = newArray(0);
	files = getTifFiles(dir, files);
	initializeLog();
	slicesAligned = 0;
	startTime = getTime();
	setBatchMode(true);
	for (i = 0; i < files.length; i++) {
		currfile = i;
		shiftPath = getShiftsFile(files[i]);
		alignFile = getAlignFile(files[i]);
		if (File.exists(shiftPath) && (overwriteResults || !File.exists(alignFile))) {
			loadShifts(shiftPath);
			open(files[i]);
			stackID = getImageID();
			slicesAligned = slicesAligned + nSlices;
			applyShiftsOnStack(stackID);
			measureCorrel(stackID);
			saveAs("tiff", alignFile);
			close();
			saveShifts(shiftPath);
		}
		print("\\Update1:"+(i+1)+"/"+files.length+" stack(s) aligned, "+slicesAligned+" slice(s) aligned in "+(getTime()-startTime)/1000+"s");
	}
	setBatchMode(false);
	print("\\Update0:Alignment and saving done.");
	print("\\Update2:");
	showStatus("Done.");
}

function button6() {
	buttonID = 6;
	verbose = true;
	message = "Choose directory containing stacks on which correlation must be computed and save";
	showStatus(message);
	dir = getDirectory(message);
	files = newArray(0);
	files = getTifFiles(dir, files);
	initializeLog();
	slicesAligned = 0;
	startTime = getTime();
	setBatchMode(true);
	for (i = 0; i < files.length; i++) {
		shiftPath = getShiftsFile(files[i]);
		alignFile = getAlignFile(files[i]);
		if (File.exists(shiftPath) && File.exists(alignFile)) {
			loadShifts(shiftPath);
			open(alignFile);
			stackID = getImageID();
			slicesAligned = slicesAligned + nSlices;
			measureCorrel(stackID);
			close();
			saveShifts(shiftPath);
		}
		print("\\Update1:"+(i+1)+"/"+files.length+" stack(s) correled, "+slicesAligned+" slice(s) correled in "+(getTime()-startTime)/1000+"s");
	}
	setBatchMode(false);
	print("\\Update0:Correlation done.");
	print("\\Update2:");
	showStatus("Done.");
}

function loadShifts(shiftPath) {
	lines = split(File.openAsString(shiftPath),"\n");
	offsets = split(lines[0], ",");
	ox = parseFloat(offsets[1]);
	oy = parseFloat(offsets[2]);
	otheta = parseFloat(offsets[3]);
	ocorrel = parseFloat(offsets[4]);
	dx2 = split(lines[1], ",");
	dx = newArray(dx2.length);
	dy2 = split(lines[2], ",");
	dy = newArray(dy2.length);
	dtheta2 = split(lines[3], ",");
	dtheta = newArray(dtheta2.length);
	correl2 = split(lines[4], ",");
	correl = newArray(correl2.length);
	for (i = 0; i < dx2.length; i++) {
		dx[i] = parseFloat(dx2[i]);
		dy[i] = parseFloat(dy2[i]);
		dtheta[i] = parseFloat(dtheta2[i]);
		correl[i] = parseFloat(correl2[i]);
	}
}

function updateParms() {
	Dialog.create("Parameters");
	Dialog.addMessage("Before being aligned with TurboReg, images are first gaussian blurred,\n"+
	"find edges is applied, a median filter is applied, images are scaled,\n"+
	"and finally cropped removing a fraction of the image from each border.");
	Dialog.addNumber("Gaussian sigma: ", sigmaGauss);
	Dialog.addNumber("Median radius: ", radiusMedian);
	Dialog.addNumber("Scale factor: ", scale);
	Dialog.addNumber("Margins to remove (align): ", marginAlign);
	Dialog.addNumber("                   Margins to remove (correl): ", marginCorrel);
	Dialog.addNumber("Extract step: ", extractStep);
	Dialog.addChoice("TurboReg method: ", methods, method);
	Dialog.addChoice("Compute alignment ", alignRefs, alignRef);
	Dialog.addNumber("Slice reference: ", sliceRef);
	if (buttonID == 2) {
		Dialog.addCheckbox("Overwrite results? (Enable if parameters changed)", overwriteResults);
		Dialog.addCheckbox("Align and save stacks? (Enable if Inter tool won't be used)", alignSaveStacks);
	}
	Dialog.show();
	sigmaGauss = Dialog.getNumber();
	radiusMedian = Dialog.getNumber();
	scale = Dialog.getNumber();
	marginAlign = Dialog.getNumber();
	marginCorrel = Dialog.getNumber();
	extractStep = Dialog.getNumber();
	method = Dialog.getChoice();
	alignRef = Dialog.getChoice();
	sliceRef = Dialog.getNumber();
	if (buttonID == 2) {
		overwriteResults = Dialog.getCheckbox();
		alignSaveStacks = Dialog.getCheckbox();
	}
}

function initializeLog() {
	print("\\Clear");
	if (buttonID == 2) {
		print("Intra stack alignment in progress...");
	} else if (buttonID == 5 || buttonID == 6) {
		print("Alignment and saving in progress...");
	}
	print("0/"+files.length+" stack aligned, 0 slice aligned");
	print("Aligning: ");
	print("Files to align:");
	for (i = 0; i < files.length; i++) {
		print("["+(i+1)+"] "+files[i]);
	}
}

function updateLog(action, curr, tot) {
	msg = action+" ["+(currfile+1)+"] "+curr+"/"+tot;
	showStatus("!"+msg);
	showProgress(curr, tot);
	if (verbose)
		print("\\Update2:"+msg);
}

function saveShifts(shiftFile) {
	f = File.open(shiftFile);
	print(f, slice+", "+ox+", "+oy+", "+otheta+", "+ocorrel);
	dxtxt = String.join(dx);
	dytxt = String.join(dy);
	dthetatxt = String.join(dtheta);
	correltxt = String.join(correl);
	print(f, dxtxt);
	print(f, dytxt);
	print(f, dthetatxt);
	print(f, correltxt);
	File.close(f);
}

function getShiftsFile(path) {
	if (lastIndexOf(path, ".tif") < 0) {
		res = "";
	} else {
		res = replace(path, ".tif", "-shifts.txt");
	}
	return res;
}

function getAlignFile(path) {
	if (lastIndexOf(path, ".tif") < 0) {
		res = "";
	} else {
		res = replace(path, ".tif", "-aligned.tif");
	}
	return res;
}

function getTifFiles(path, output) {
	list = getFileList(path);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/"))
		   output = getTifFiles(""+path+list[i], output);
		else if (endsWith(list[i], ".tif") && !endsWith(list[i], "-aligned.tif"))
		   output = Array.concat(output, path + list[i]);
	}
	return output;
}

function isStack() {
	res = false;
	imlist = getList("image.titles");
	if (imlist.length > 0) {
		if (nSlices > 1) {
			res = true;
		}
	}
	return res;
}

function computeCurrentStackShifts(stackID) {
	selectImage(stackID);
	run("Select None");
	slice = -1;
	if (matches(alignRef,alignRefs[0])) {
		alignStackSequentially(stackID);
	} else {
		alignStackOnSlice(stackID);
	}
	minimiseTranslation();
}

function minimiseTranslation() {
	rankdx = Array.rankPositions(dx);
	rankdy = Array.rankPositions(dy);
	dxshift = dx[rankdx[round(dx.length/2)]];
	dyshift = dy[rankdy[round(dy.length/2)]];
	for (i = 0; i < dx.length; i++) {
		dx[i] = dx[i] - dxshift;
		dy[i] = dy[i] - dyshift;
	}
}

function applyShiftsOnStack(stackID) {
	selectImage(stackID);
	n = nSlices;
	for (i = 0; i < n; i++) {
		updateLog("Applying shift", i+1, n);
		setSlice(i+1);
		if (dtheta[i]+otheta != 0) {
			run("Rotate... ", "angle="+(dtheta[i]+otheta)+" grid=1 interpolation=Bicubic");
		}
		run("Translate...", "x="+(dx[i]+ox)+" y="+(dy[i]+oy)+" interpolation=Bicubic");
	}
}

function plotShifts() {
	Plot.create("Movements", "Slice", "Shift");
	Plot.setColor("blue");
	Plot.add("line", dx);
	Plot.setColor("red");
	Plot.add("line", dy);
	Plot.setLegend("dx\tdy");
	Plot.show();
	Plot.setLimitsToFit();
	Plot.create("Correlation", "Slice", "Correlation", correl);
	Plot.show();
}

function alignStackSequentially(stack) {
	selectImage(stack);
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	dx = newArray(slices);
	dy = newArray(slices);
	//dxy = newArray(slices);
	dtheta = newArray(slices);
	correl = newArray(slices);
	setSlice(1);
	makeImgForAlign("ref");
	for (i = 2; i <= slices; i++) {
		selectImage(stack);
		setSlice(i);
		updateLog("Computing shift", i, slices);
		makeImgForAlign("toAlign");
		res = useTurboReg(method, "ref", "toAlign");
		close("ref");
		selectWindow("toAlign");
		rename("ref");
		selectImage(stack);
		setSlice(i);
		if (matches(method, "rigidBody")) {
			dtheta[i-1] = dtheta[i-2] + res[2];
		}
		dx[i-1] = dx[i-2] + res[0]/scale;
		dy[i-1] = dy[i-2] + res[1]/scale;
		//dxy[i-1] = sqrt(dx[i-1]*dx[i-1]+dy[i-1]*dy[i-1]);
	}
	close("ref");
}

function alignStackOnSlice(stack) {
	if (buttonID == 3) {
		step = 1;
	} else {
		step = maxOf(extractStep,1);
	}
	if (matches(alignRef,alignRefs[2])) {
		slice = sliceRef;
	}
	selectImage(stack);
	run("Select None");
	slices = nSlices;
	dx = newArray(slices);
	dy = newArray(slices);
	dtheta = newArray(slices);
	correl = newArray(slices);
	if (slice < 1 || slice > slices) {
		if (slices <= 21 || step == 1) {
			run("Duplicate...", "title=extract duplicate");
		} else {
			run("Slice Keeper", "first="+round(step/2)+" last="+slices+" increment="+step);
			rename("extract");
		}
		slicesExtract = nSlices;
		dxy = newArray(slicesExtract);
		run("Z Project...", "projection=Median");
		rename("tempmed");
		makeImgForAlign("ref");
		close("tempmed");
		for (i = 0; i < slicesExtract; i++) {
			updateLog("Computing shift", i+1-slicesExtract, slices);
			selectWindow("extract");
			setSlice(i+1);
			makeImgForAlign("toAlign");
			res = useTurboReg(method, "ref", "toAlign");
			close("toAlign");
			dxy[i] = sqrt(res[0]*res[0]+res[1]*res[1])/scale;
		}
		shiftsRanks = Array.rankPositions(dxy);
		if (slices <= 21 || step == 1) {
			slice = shiftsRanks[0] + 1;
		} else {
			slice = shiftsRanks[0] * step + round(step/2);
		}
		close("ref");
		close("extract");
	}
	selectImage(stack);
	setSlice(slice);
	makeImgForAlign("ref");
	for (i = 0; i < slices; i++) {
		updateLog("Computing shift", i+1, slices);
		selectImage(stack);
		setSlice(i+1);
		makeImgForAlign("toAlign");
		res = useTurboReg(method, "ref", "toAlign");
		close("toAlign");
		if (matches(method, "rigidBody")) {
			dtheta[i] = res[2];
		}
		dx[i] = res[0]/scale;
		dy[i] = res[1]/scale;
	}
	close("ref");
}

function measureCorrel(stack) {
	selectImage(stack);
	nslice = nSlices;
	correl = newArray(nslice);
	x = getWidth();
	y = getHeight();
	if (slice < 1 || slice > nslice) {
		dxy = newArray(nslice);
		for (i = 0; i < nslice; i++) {
			dxy[i] = sqrt(pow(dx[i],2)+pow(dy[i],2));
		}
		rankdxy = Array.rankPositions(dxy);
		slice = rankdxy[round(nslice/2)];
	}
	setSlice(slice);
	run("Duplicate...", "title=corref");
	run("Gaussian Blur...", "sigma=3");
	makeRectangle(marginCorrel*x,marginCorrel*y,(1-2*marginCorrel)*x,(1-2*marginCorrel)*y);
	run("Crop");
	meanref = getValue("Mean");
	sigmaref = getValue("StdDev");
	for (n = 0; n < nslice; n++) {
		selectImage(stack);
		setSlice(n+1);
		updateLog("Computing correl", n+1, nslice);
		run("Duplicate...", "title=tarref");
		run("Gaussian Blur...", "sigma=3");
		makeRectangle(marginCorrel*x,marginCorrel*y,(1-2*marginCorrel)*x,(1-2*marginCorrel)*y);
		run("Crop");
		meantar = getValue("Mean");
		sigmatar = getValue("StdDev");
		imageCalculator("Multiply create 32-bit", "corref","tarref");
		meanproduct = getValue("Mean");
		close();
		close("tarref");
		correl[n] = (meanproduct - meanref * meantar) / (sigmaref * sigmatar);
	}
	close("corref");
	selectImage(stack);
}

function makeImgForAlign(name) {
	run("Duplicate...", "title=tmpref");
	run("Gaussian Blur...", "sigma="+sigmaGauss);
	run("Find Edges", " ");
	//run("Minimum...", "radius=1 stack");
	run("Median...", "radius="+radiusMedian);
	if (scale != 1) {
		run("Scale...", "x="+scale+" y="+scale+" z=1.0 interpolation=Bilinear average process create");
	}
	rename(name);
	close("tmpref");
	x = getWidth();
	y = getHeight();
	makeRectangle(marginAlign*x,marginAlign*y,(1-2*marginAlign)*x,(1-2*marginAlign)*y);
	run("Crop");
}

function useTurboReg(method, imgA, imgB) {
	// outputs the transformation to apply to imgB so that it matches imgA
	// translation gives dx, dy
	// rigidBody gives dx, dy, theta
	// others are not implemented yet
	selectWindow(imgA);
	wA = getWidth();
	hA = getHeight();
	selectWindow(imgB);
	wB = getWidth();
	hB = getHeight();
	turboRegTxt = "-align -window "+imgA+" 0 0 "+(wA-1)+" "+(hA-1)+" -window "+imgB+" 0 0 "+(wB-1)+" "+(hB-1)+" -"+method;
	if (matches(method, "translation")) { // one centered landmark
		turboRegTxt += " "+(wA/2)+" "+(hA/2)+" "+(wB/2)+" "+(hB/2);
	} else if (matches(method, "rigidBody")) {
		turboRegTxt += " "+(wA/2)+" "+(hA/2)+" "+(wB/2)+" "+(hB/2)+" "+(wA*0.15)+" "+(hA*0.5)+" "+(wB*0.15)+" "+(hB*0.5)+" "+
						(wA*0.85)+" "+(hA*0.5)+" "+(wB*0.85)+" "+(hB*0.5);
	} else if (matches(method, "scaledRotation")) {
		turboRegTxt += " "+(wA*0.15)+" "+(hA/2)+" "+(wB*0.15)+" "+(hB/2)+" "+(wA*0.85)+" "+(hA/2)+" "+(wB*0.85)+" "+(hB/2);
	} else if (matches(method, "affine")) {
		turboRegTxt += " "+(wA/2)+" "+(hA*0.15)+" "+(wB/2)+" "+(hB*0.15)+" "+(wA*0.15)+" "+(hA*0.85)+" "+(wB*0.15)+" "+(hB*0.85)+" "+
						(wA*0.85)+" "+(hA*0.85)+" "+(wB*0.85)+" "+(hB*0.85);
	} else if (matches(method, "bilinear")) {
		turboRegTxt += " "+(wA*0.15)+" "+(hA*0.15)+" "+(wB*0.15)+" "+(hB*0.15)+" "+(wA*0.15)+" "+(hA*0.85)+" "+(wB*0.15)+" "+(hB*0.85)+" "+
						(wA*0.85)+" "+(hA*0.15)+" "+(wB*0.85)+" "+(hB*0.15)+" "+(wA*0.85)+" "+(hA*0.85)+" "+(wB*0.85)+" "+(hB*0.85);
	} else {
		print("error in the method name given, \""+method+"\" is not valid for useTurboReg method");
		return newArray(0);
	}
	turboRegTxt += " -hideOutput";
	run("TurboReg ", turboRegTxt);
	if (matches(method, "translation")) {
		res = newArray(2); // translations x and y
		res[0] = getResult("sourceX", 0)-getResult("targetX", 0);
		res[1] = getResult("sourceY", 0)-getResult("targetY", 0);
	} else if (matches(method, "rigidBody")) {
		res = newArray(3); // translations x and y, rotation theta
		res[0] = getResult("sourceX", 0)-getResult("targetX", 0);
		res[1] = getResult("sourceY", 0)-getResult("targetY", 0);
		res[2] = 180/PI*atan2(getResult("sourceY",2)-getResult("sourceY",1),getResult("sourceX",2)-getResult("sourceX",1)); // angle in degrees
	} else {
		res = newArray(0);
		print(method, "not implemented yet in the function useTurboReg, yet");
//	} else if (matches(method, "scaledRotation")) {
//	} else if (matches(method, "affine")) {
//	} else if (matches(method, "bilinear")) {
	}
	return res;
}

