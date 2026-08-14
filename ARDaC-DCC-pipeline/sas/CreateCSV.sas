/*********************************************
PROGRAM NAME: CreateCSV.sas
MACRO NAME: CreateCSV
		Description:  
			Creates CSV files for all SAS datasets in folder passed to macro. 
		Parameters: 
				-adsfolder: Location of ADS folder containing the datasets to be exported as CSV
 		Examples:
				Example 1: All parameters with arguments
					%CreateDataDictionary(I:\Projects\Cancer\IUSCC\IUCRO-0408\DataMgt\Temp);
		Author:  Andrew Borst
		Date created:  February 2017 
**********************************************/

%macro CreateCSV(adsfolder,outputfolder);
	libname templib "&adsfolder.";

	*libname templib "I:\Projects\TREAT\Data Management\OnCore Data\Datasets\02FEB17";

	/*create a new dataset containing the name of the datasets to be exported as CSV*/
	data varcount;
		set sashelp.vtable;
		where libname ='TEMPLIB';
		count+1;
	run;

	* Creates a dataset with ALL the variables in ALL the datasets of the templib library;
	proc sql;
		select count(*) into :n from sashelp.vmember where libname = "TEMPLIB";
	quit;

	%do i = 1 %to &n;
		/*the following statement selects the corresponding dataset based on the name picked from the counter "i" on the statment */
		proc sql noprint;
			select memname into :datasetname separated by ''  from work.varcount where count = &i and memname ^= "VARCOUNT"; 
		quit;

		PROC EXPORT DATA= templib.&datasetname
            OUTFILE= "&outputfolder\&datasetname..csv" 
            DBMS=CSV REPLACE;
     		PUTNAMES=YES;
		RUN;

	%end;	
%mend;
