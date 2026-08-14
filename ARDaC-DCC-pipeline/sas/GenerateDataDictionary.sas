
/*********************************************
PROGRAM NAME: Generate Data Dictionary.sas
MACRO NAME: CreateDataDictionary
		Description:  
				Generates a data dictionary (code book) by gathering variable information for a set of datasets
				all residing in a particular file location ("ADS" folder). This data dictionary is exported as
				a file, but will also exist in the WORK directory as the dataset "datadictionary".
		Parameters: 
				-adsfolder: Location of ADS folder containing the datasets to be listed in the data dictionary
				-ddlocation: Full file name of the data dictionary to create
				-domdeclocation: OPTIONAL - File location of a spreadsheet that lists the forms and the corresponding
					domains / datasets they were assigned to
				-optionsyn: OPTIONAL - YES if data dictionary should list the "options" (aka format values) for 
					each variable, when applicable. The options will be extracted from whichever formats are 
					currently loaded in the WORK directory.
 		Examples:
				Example 1: All parameters with arguments
					%CreateDataDictionary(I:\Projects\Cancer\IUSCC\IUCRO-0408\DataMgt\Temp, 
						I:\Projects\Cancer\IUSCC\IUCRO-0408\DataDictionary\Data Dictionary.xlsx,
						I:\Projects\Cancer\IUSCC\IUCRO-0408\DataDictionary\Domain Decisions for 0408.xlsx,
						YES);
				Example 2: Optional parameters left off (basic data dictionary)
					%CreateDataDictionary(I:\Projects\Cancer\IUSCC\IUCRO-0408\DataMgt\Temp, 
						I:\Projects\Cancer\IUSCC\IUCRO-0408\DataDictionary\Data Dictionary.xlsx);
		Author:  Anna Kispert
		Date created:  July 2015
**********************************************/

%macro CreateDataDictionary(adsfolder, ddlocation, domdeclocation, optionsyn);

/* PART 1: Get the list of domains and each of their variables in the ADS folder location */

	libname templib "&adsfolder.";

	* Creates a dataset with ALL the variables in ALL the datasets of the templib library;
	proc datasets lib = templib noprint;
		contents data = _all_ out = work.tcont1;
	quit; run;

	* Drop non-essential variables and convert the TYPE variable to be text;
	data tcont2;
		set tcont1 (keep = MEMNAME NAME TYPE LENGTH FORMAT INFORMAT LABEL);

		rename MEMNAME = DOMAIN
			   NAME = VARIABLE;

		format TYPE2 $20.;
		if TYPE = 1 then TYPE2 = 'Numeric';
		else if TYPE = 2 then TYPE2 = 'Character';
		drop TYPE;
		rename TYPE2 = TYPE;
	run;

	* Create the datadictionary dataset, which will be output as an excel file below;
	data datadictionary;
		retain DOMAIN VARIABLE TYPE LENGTH FORMAT INFORMAT LABEL;
		set tcont2;

		* Create the NOTES variable (will be left blank -- to be filled out by DM);
		NOTES = '';

		label DOMAIN = 'Dataset / Domain'
			  VARIABLE = 'Variable'
			  TYPE = 'Type'
			  LENGTH = 'Length'
			  FORMAT = 'Format'
			  INFORMAT = 'Informat'
			  LABEL = 'Label'
			  NOTES = 'Notes';
	run;

	* Sort the datadictionary by domain / dataset name;
	proc sort data = datadictionary; 
		key DOMAIN;
	run;


/* PART 2: Get the names of the forms that went into each domain, if applicable (OPTIONAL) */

	%if "&domdeclocation." ne "" %then %do;

		* Get the extension of the file that will be created;
		data _null_;
			FILEPATH = "&domdeclocation.";
			EXTPOS = length(FILEPATH) - length(scan(FILEPATH,-1,'.'));
			EXT = substr(FILEPATH,EXTPOS+1,length(FILEPATH)-EXTPOS);
			call symput('domdeclocextension', EXT);
		run;

		* Import the list of domains and their corresponding forms;
		proc import out = dd1 
			datafile = "&domdeclocation."
			dbms = &domdeclocextension. REPLACE;
			getnames = yes;
		run;

		* Only keep rows where a form has a designated domain / dataset name (and vice versa);
		data dd2;
			set dd1 (keep = FORM DOMAIN);
			if FORM = '' or DOMAIN = '' then delete;
			DOMAIN = upcase(DOMAIN); *Need these to be all upper case for the merge;
		run;

		proc sort data = dd2; by DOMAIN; run;

		* If multiple forms are assigned to one domain, this will merge those form names into one variable.
		  For example, if forms TX-001 and TX-002 were combined to create the TOXICITY dataset, then the
		  FORMS variable will contain the string 'TX-001, TX-002';
		data dd3;
			set dd2;
			by DOMAIN;

			format FORMS $200.;
			retain FORMS;
			if first.DOMAIN then FORMS = FORM;
			else FORMS = trim(FORMS) || "; " || trim(FORM);
		run;

		* Drop all but the last occurence of a domain name to get the one-to-one list of domains and
		  their corresponding form(s);
		data dd4;
			set dd3;

			by DOMAIN;
			if last.DOMAIN then output;

			drop FORM;
		run;

		* Merge the FORMS information into the datadictionary dataset;
		data datadictionary;
			retain DOMAIN FORMS VARIABLE TYPE LENGTH FORMAT INFORMAT LABEL;
			format DOMAIN $32.; *Format set so dataset names do not get cut off in the merge;
			merge datadictionary (in = a) dd4;
			by DOMAIN;
			if a;
			IF DOMAIN IN ("AHNS_FORMAT_DATASET","AHN_FORMAT_DATASET","AHNAD_FORMAT_DATASET") THEN DELETE; *Ronny. O;
			label FORMS = 'Form(s)';
		run;

	%end;


/* PART 3: Get the list of format options (OPTIONAL) */

	%if &optionsyn. = YES %then %do;

		* Capture the currently loaded formats as a dataset;
		proc format cntlout = fmtopts1; run;

		data fmtopts2;
			set fmtopts1 (keep = FMTNAME START LABEL TYPE);
			if TYPE = 'C' then do;
				FMTNAME = '$' || strip(FMTNAME);
				START = "'" || strip(START) || "'";
			end;
		run;

		proc sort data = fmtopts2; by FMTNAME START; run;

		data fmtopts3;
			set fmtopts2;
			by FMTNAME;

			format FMTOPTIONS $10000.;
			retain FMTOPTIONS;
			if first.FMTNAME then FMTOPTIONS = strip(START) || ', ' || strip(LABEL);
			else FMTOPTIONS = trim(FMTOPTIONS) || ' | ' || strip(START) || ', ' || strip(LABEL);
		run;

		data fmtopts4;
			set fmtopts3;

			by FMTNAME;
			if last.FMTNAME then output;

			drop START LABEL TYPE;

			rename FMTNAME = FORMAT;
		run;

		* Merge the format options in with the datadictionary dataset;
		proc sort data = datadictionary; by FORMAT; run;
		proc sort data = fmtopts4; by FORMAT; run;

		data datadictionary;
			retain DOMAIN FORMS VARIABLE TYPE LENGTH FORMAT FMTOPTIONS INFORMAT LABEL;
			merge datadictionary (in = a) fmtopts4;
			by FORMAT;
			if a;
			IF DOMAIN IN ("AHNS_FORMAT_DATASET","AHN_FORMAT_DATASET","AHNAD_FORMAT_DATASET") THEN DELETE; *Ronny. O;
			label FMTOPTIONS = 'Choices';
		run;

		* Restore original sorting order;
		proc sort data = datadictionary; by DOMAIN; run;

	%end;

	%if &optionsyn. = YES:TABBED %then %do;

		* Capture the currently loaded formats as a dataset;
		proc format cntlout = formats1; run;

		proc sort data = formats1; by FMTNAME; run;

		data formats;
			set formats1 (keep = FMTNAME START LABEL TYPE);
			if TYPE = 'C' then do;
				FMTNAME = '$' || strip(FMTNAME);
				START = "'" || strip(START) || "'";
			end;
			else do;
				START = strip(START);
			end;

			drop TYPE;

			label FMTNAME = 'Format name'
				  START = 'Value'
				  LABEL = 'Value label';
		run;

	%end;


/* PART 4: Export */

	* Create a new dataset with the name "Variables" so that the spreadsheet tab will have this name;
	* Modified to sort by domain and variable - Andrew Borst 01/10/2016;
	proc sort data=datadictionary out=variables;
		key domain;
		key variable;
	run;
	
	* Get the extension of the file that will be created;
	data _null_;
		FILEPATH = "&ddlocation.";
		EXTPOS = length(FILEPATH) - length(scan(FILEPATH,-1,'.'));
		EXT = substr(FILEPATH,EXTPOS+1,length(FILEPATH)-EXTPOS);
		call symput('ddlocextension', EXT);
	run;
	%put &ddlocextension.;

	* Export the data dictionary as a new file;
	%if &optionsyn. = YES:TABBED %then %do;	
		proc export data = variables outfile = "&ddlocation." dbms = excel replace label; sheet='Variables';
		proc export data = formats outfile = "&ddlocation." dbms = excel replace label; sheet='Formats';
		run;
	%end;
	%else %do;
		proc export data = variables outfile = "&ddlocation." dbms = &ddlocextension. replace label;
		run;
	%end;

	* Delete all of the temporary datasets used within this macro - keep datadictionary in case
	  further manipulation is desired;
	proc datasets nolist;
		delete dd1 dd2 dd3 dd4 fmtopts1 fmtopts2 fmtopts3 fmtopts4 formats formats1 tcont1 tcont2;
	quit; run;

%mend;
