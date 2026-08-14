** plan of attack
	Load AHN files (OBS and RCT)
	convert to CSV
	Export on their own subfolders;

libname RCT "I:\Projects\AlcHepNet\DataManagement\Datasets\Final\RCT";
libname OBS "I:\Projects\AlcHepNet\DataManagement\Datasets\Final\OBS";

*load the formats**;
libname inset 'I:\Projects\AlcHepNet\DataManagement\Data\Last_Export\Clean Export';
/**/
proc format library=work cntlin=inset.Ahnad_format_dataset;run;
proc format library=work cntlin=inset.Ahns_format_dataset;run;
proc format library=work cntlin=inset.Ahn_format_dataset;run;

options fmtsearch=(obs.ahn_format_file_sdoh,inset.ahns_format_file);


%include "I:\Projects\AlcHepNet\DataManagement\SAS programs\AHN_format.sas";
%include "I:\Projects\AlcHepNet\DataManagement\SAS programs\aeterm_.sas";
%include "I:\Projects\AlcHepNet\DataManagement\SAS programs\AHN ConMeds Formats.sas";
%include "I:\Projects\AlcHepNet\DataManagement\Reports\AHN OBS-RCT Update Request\AHN_format.sas";
%INCLUDE "I:\Projects\AlcHepNet\DataManagement\Reports\Infection Data\INFECTIONS_CAT_TYPE_FORMATS.sas";



%include "I:\Projects\AlcHepNet\Data for Nanxin\CreateCSV.sas";
%include "I:\Projects\AlcHepNet\Data for Nanxin\GenerateDataDictionary.sas";


*export CSV datasets to RCT folder ***;
%CreateCSV(I:\Projects\AlcHepNet\DataManagement\Datasets\Final\RCT,
I:\Projects\AlcHepNet\Data for Nanxin\RCT Final Datasets);

	%CreateDataDictionary(I:\Projects\AlcHepNet\DataManagement\Datasets\Final\RCT,
	I:\Projects\AlcHepNet\Data for Nanxin\RCT_DataDictionary.xlsx);



*export CSV datasets to OBS folder ***;
%CreateCSV(I:\Projects\AlcHepNet\DataManagement\Datasets\Final\OBS,
I:\Projects\AlcHepNet\Data for Nanxin\OBS Final Datasets);

	%CreateDataDictionary(I:\Projects\AlcHepNet\DataManagement\Datasets\Final\OBS,
	I:\Projects\AlcHepNet\Data for Nanxin\OBS_DataDictionary.xlsx);


