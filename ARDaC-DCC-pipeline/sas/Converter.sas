

libname inset 'I:\Projects\AlcHepNet\TREAT Data for Nanxin\SAS DATA';
/**/
proc format library=work cntlin=inset.Ahnad_format_dataset;run;
proc format library=work cntlin=inset.Ahns_format_dataset;run;
proc format library=work cntlin=inset.Ahn_format_dataset;run;

libname output "I:\Projects\AlcHepNet\InTeam Data\Output Data";



	PROC EXPORT DATA= inset.IT_VISITS
            OUTFILE= "I:\Projects\AlcHepNet\TREAT Data for Nanxin\CSV Datasets\IT_VISITS.csv" 
            DBMS=CSV REPLACE;
     		PUTNAMES=YES;
		RUN;

		PROC EXPORT DATA= inset.IT_SCREEN_BASELINE
            OUTFILE= "I:\Projects\AlcHepNet\TREAT Data for Nanxin\CSV Datasets\IT_SCREEN_BASELINE.csv" 
            DBMS=CSV REPLACE;
     		PUTNAMES=YES;
		RUN;

	
