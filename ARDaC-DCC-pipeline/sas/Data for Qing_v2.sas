/*
plan of development:
	import data from RedCap
	import Data from AHN
	Import external data

	Merge data
		I'll need to first extract the data needed from AHN into a single dataset. 
		Then ill start to consolidate similar variables

	Export data
*/

*import Data from redcap;
libname inset 'I:\Projects\AlcHepNet\DataManagement\Data\Last_Export\clean export';
/**/
proc format library=work cntlin=inset.Ahnad_format_dataset;run;
proc format library=work cntlin=inset.Ahns_format_dataset;run;
proc format library=work cntlin=inset.Ahn_format_dataset;run;

libname output "I:\Projects\AlcHepNet\InTeam Data\Output Data";
****************************************************************************************;


*import external data;
**************************************SCREENING AND BASELINE DATA**********************************************;
***************************************************************************************************************;
proc import out=SCREENING_N_BASELINE
file="I:\Projects\AlcHepNet\InTeam Data\Data from Ana 2021-11-19\InTeam full database.xlsx"

dbms=excel replace;
sheet ="Screening&BaselineInfo";
/*GUESSINGROWS=2000;*/
run;

DATA SCREENING_N_BASELINE2;
retain subject_id site_name auth_site_id arm visit_sort set_name registration_date2 consent_date 
year_inclusion admit_date2 start_date exit_date2 subject_status pt_type birth_year AGE sex2 race2;

 
SET SCREENING_N_BASELINE;

*assing visit #1;
visit_sort =1;
SET_NAME= "Baseline (Day 0)";

* "=5" value does not exist on AHN,	6=white ,777= unknown;
if race in(1,2,3,4,5) then race2=race;
if race=5 then race2=6;
if race=6 then race2=999;

*Sex is different too...;
if sex ="male" then sex2=1;
if sex ="female" then sex2=2;

if pt_type=1 then ARM="Control";*create an arm variable, might be useful in the future;
if pt_type=0 then ARM="Cases";
if pt_type=1 then delete;

registration_date2=input(scan(registration_date,1,' '),anydtdte32.);
exit_date2= input(exit_date, date11.);
admit_date2= input(admit_date, date11.);
biopsy_date2= input(biopsy_date, date11.);


drop f122-f125 sex registration_date exit_date admit_date biopsy_date race;

rename   site_name= it_site sex2=sex 
	registration_date2=registration_date exit_date2=exit_date admit_date2=admit_date
	biopsy_date2=biopsy_date;

format race2 race_all. sex2 sex_.
	registration_date2  exit_date2 admit_date2 biopsy_date2 date9. ;

keep subject_id site_name auth_site_id registration_date2 consent_date year_inclusion admit_date2 start_date 
exit_date2 subject_status pt_type birth_year AGE sex2 race2 ethnicity   prior_tx days_tx 
pred_tx pred_cum pento_tx pendo_cum hep_b hep_b_antigen hep_b_dna hep_c hep_rna race_ctrl 
   biopsy biopsy_date2  fibrosis_stage lobular_fibrosis pericellular_fibrosis steatosis 
mallory_bodies bilirubinostasis ballooning giant_mitochondria pmn_infiltration inflammatory_grade 
other_findings other_findings_txt sex2 visit_sort set_name 

 audit_1 audit_2  audit_3  audit_4 audit_5  audit_6 audit_7  audit_8  audit_9  audit_10  ;
run;

proc print data=SCREENING_N_BASELINE; run;

***************************************************************************************************************;

**************************************SCHEDULED VISITS AND DISCHARGE*******************************************;
***************************************************************************************************************;
proc import out=VISITS_N_DISCHARGE
file="I:\Projects\AlcHepNet\InTeam Data\Data from Ana 2021-11-19\InTeam full database.xlsx"

dbms=excel replace;
sheet ="ScheduledVisits+DischargeInfo";
/*GUESSINGROWS=2000;*/
run;


data visits_discharge2;
retain subject_id auth_site_id set_name visit_sort visit_date2 consent_date exit_date lab_date2;
	set VISITS_N_DISCHARGE;
	
	if pt_type=1 then delete;

	*move the platelets x_10_3_ul to platelets_value_10to9_l
		( the conversion is different but the value is the same);
	if platelets_units ="x_10_3_ul"  and  platelets_value_10to9_l = "" then platelets_value_10to9_l= platelets_value_10to3_ul;

	if wbc_count_units ="x_10_3_ul"  and wbc_10to9_l = "" then wbc_10to9_l= wbc_value_10to3_ul;

*convert from g/l to g/dl;


	if albumin_units="g_dl" then albumin=input(albumin_value_g_dl,5.);
	if albumin_units="g_l" then do; 
		albumin_value_g_dl =albumin_value_g_l*0.1;
		albumin= input(albumin_value_g_dl,5.);
	end; 

	if hemoglobin_units="g_dl" then hemoglobin=input(hemoglobin_value_g_dl,5.);
	if hemoglobin_units="g_l" then do;
		hemoglobin_value_g_dl =hemoglobin_value_g_l*0.1;
		hemoglobin=input(hemoglobin_value_g_dl,5.);
	end;
	
*convert from umol to md/dl;
	* a few entries were done with comas(,) this was causing errors. Im changin to dots(.);
	bilirubin_value_mg_dl=tranwrd(bilirubin_value_mg_dl,",",".");
	bilirubin_value_umol_l=tranwrd(bilirubin_value_umol_l,",",".");

/*	Formula to calculate mg/dl from mmol/l: mg/dl = 18 × mmol/l */
	if bilirubin_units="mg_dl" then  bili_tot=input(bilirubin_value_mg_dl, 5.); 
	if bilirubin_units="umol_l" then do; 
		bilirubin_value_mg_dl =(bilirubin_value_umol_l*0.0113);
		bili_tot=input(bilirubin_value_mg_dl,5.);
	end;

	if creatinine_units="mg_dl" then creat=input(creatinine_value_mg_dl,5.);
	if creatinine_units="umol_l" then do;
		creatinine_value_mg_dl =(creatinine_value_umol_l*0.0113);
		creat=input(creatinine_value_mg_dl,5.);
	end;

	if glucose_units="mg_dl" then fglucose=input(glucose_value_mg_dl,5.);
	if glucose_units="mmol_l" then do;
		glucose_value_mg_dl =(glucose_value_mmol_l*18);
		fglucose=input(glucose_value_mg_dl,5.);
	end;

*more convertions;
	alk_phos2 = input(alk_phos ,  8.);
	alt2  = input(alt ,  8.);
	 ast2  = input(ast ,  8.);

	inr2  = input(inr  ,  8.);
	sodium2  = input(sodium  ,  8.);
	 wbc2  = input(wbc_10to9_l  ,  8.);
	heart_rate2  = input(heart_rate  ,  8.);
	/*systolic  = input(systolic,8.);*/
	/*diastolic  = input(diastolic,8.);*/
	oxygen_sat2  = input(oxygen_sat ,  8.);
	wt_kg2  = input( wt_kg,  8.);
	 ht_cm2  = input(ht_cm  ,  8.);
	ascites2  = input(ascites  ,  8.);
	 encephalopathy2  = input( encephalopathy,  8.);
	antibiotics2  = input(antibiotics  ,  8.);
	steroids2  = input(steroids ,  8.);
	ptx2  = input(ptx ,  8.);
	alcohol_found2  = input(alcohol_found ,  8.);

	visit_date2= input (visit_date,anydtdte32.);
	lab_date2= input(lab_date,anydtdte32.);
	pt=input(prothrombin_time,5.);


drop alk_phos alt    ast   inr  sodium   wbc heart_rate oxygen_sat 
wt_kg   ht_cm ascites  encephalopathy  antibiotics steroids ptx  alcohol_found  visit_date
labe_date;

rename 
	visit_date2=visit_date lab_date2=lab_date	platelets_value_10to9_l =platelet
	 prothrombin_time=pt cholesterol_value_mg_dl=chol_tot triglycerides_value_mg_dl=triglyceride

	alk_phos2=alk_phos alt2  =alt  ast2  = ast  inr2  =inr
sodium2  =sodium  wbc2 =wbc heart_rate2 =heart_rate oxygen_sat2  =oxygen_sat
wt_kg2  =wt_kg  ht_cm2 =ht_cm ascites2 =ascites  encephalopathy2 = encephalopathy
antibiotics2=antibiotics steroids2 =steroids ptx2  =ptx alcohol_found2= alcohol_found ;
;



keep 
subject_id auth_site_id set_name visit_sort visit_date2 consent_date exit_date pt_type 
albumin_value_g_dl  alk_phos  bilirubin_value_mg_dl creatinine_value_mg_dl
  lab_date2 platelets_value_10to9_l  child_pugh prothrombin_time 
cholesterol_value_mg_dl triglycerides_value_mg_dl  glucose_value_mg_dl potassium 

	glucose_value_mg_dl creatinine_value_mg_dl 	bilirubin_value_mg_dl 
	albumin_value_g_dl 	platelets_value_10to9_l 
	 prothrombin_time cholesterol_value_mg_dl triglycerides_value_mg_dl
 heart_rate res_rate oxygen_sat  
antibiotics_specify steroid_dose ptx_dose other_tx  intervention alcohol_found 

alk_phos2
alt2  
 ast2  

inr2  
sodium2  
 wbc2 
heart_rate2 
oxygen_sat2  
wt_kg2  
 ht_cm2 
ascites2 
 encephalopathy2  
antibiotics2
steroids2 
ptx2  
alcohol_found2
fglucose creat 
bili_tot hemoglobin albumin 
;

format visit_date2 lab_date2 date9.;
run;


***************************************************************************************************************;


**************************************UNSCHEDULED**************************************************************;
***************************************************************************************************************;
proc import out=UNSCHEDULED
file="I:\Projects\AlcHepNet\InTeam Data\Data from Ana 2021-11-19\InTeam full database.xlsx"

dbms=excel replace;
sheet ="Unscheduled";
/*GUESSINGROWS=2000;*/
run;


data UNSCHEDULED2;
retain subject_id auth_site_id set_name visit_sort visit_date2 consent_date exit_date lab_date2;
set UNSCHEDULED;
if pt_type=1 then delete;
	if platelets_units ="x_10_3_ul"  and  platelets_value_10to9_l = "" then platelets_value_10to9_l= platelets_value_10to3_ul;

	if wbc_count_units ="x_10_3_ul"  and wbc_10to9_l = "" then wbc_10to9_l= wbc_value_10to3_ul;

*convert from g/l to g/dl;

	if albumin_units="g_dl" then albumin=input(albumin_value_g_dl,5.);
	if albumin_units="g_l" then do; 
		albumin_value_g_dl =albumin_value_g_l*0.1;
		albumin= input(albumin_value_g_dl,5.);
	end; 

	if hemoglobin_units="g_dl" then hemoglobin=input(hemoglobin_value_g_dl,5.);
	if hemoglobin_units="g_l" then do;
		hemoglobin_value_g_dl =hemoglobin_value_g_l*0.1;
		hemoglobin=input(hemoglobin_value_g_dl,5.);
	end;
	
*convert from umol to md/dl;
	* a few entries were done with comas(,) this was causing errors. Im changin to dots(.);
	bilirubin_value_mg_dl=tranwrd(bilirubin_value_mg_dl,",",".");
	bilirubin_value_umol_l=tranwrd(bilirubin_value_umol_l,",",".");

/*	Formula to calculate mg/dl from mmol/l: mg/dl = 18 × mmol/l */
	if bilirubin_units="mg_dl" then  bili_tot=input(bilirubin_value_mg_dl, 5.); 
	if bilirubin_units="umol_l" then do; 
		bilirubin_value_mg_dl =(bilirubin_value_umol_l*0.0113);
		bili_tot=input(bilirubin_value_mg_dl,5.);
	end;

	if creatinine_units="mg_dl" then creat=input(creatinine_value_mg_dl,5.);
	if creatinine_units="umol_l" then do;
		creatinine_value_mg_dl =(creatinine_value_umol_l*0.0113);
		creat=input(creatinine_value_mg_dl,5.);
	end;

	if glucose_units="mg_dl" then fglucose=input(glucose_value_mg_dl,5.);
	if glucose_units="mmol_l" then do;
		glucose_value_mg_dl =(glucose_value_mmol_l*18);
		fglucose=input(glucose_value_mg_dl,5.);
	end;

	visit_date2= input (visit_date,anydtdte32.);
	lab_date2= input(lab_date,anydtdte32.);

	triglyceride= input(triglycerides_value_mg_dl,5.);
	pt=input(prothrombin_time,5.);

drop visit_date lab_date;
rename
	platelets_value_10to9_l =platelet	wbc_10to9_l =wbc  cholesterol_value_mg_dl=chol_tot 
	visit_date2=visit_date lab_date2=lab_date ;


keep 
subject_id auth_site_id set_name visit_sort visit_date2 consent_date exit_date pt_type 
albumin_value_g_dl  alk_phos alt ast bilirubin_value_mg_dl creatinine_value_mg_dl
 inr lab_date2 platelets_value_10to9_l sodium wbc_10to9_l child_pugh prothrombin_time 
cholesterol_value_mg_dl triglycerides_value_mg_dl  glucose_value_mg_dl potassium 

	glucose_value_mg_dl creatinine_value_mg_dl 	bilirubin_value_mg_dl 
	 albumin_value_g_dl 	platelets_value_10to9_l 
	 prothrombin_time cholesterol_value_mg_dl triglycerides_value_mg_dl
 heart_rate systolic diastolic res_rate oxygen_sat wt_kg ht_cm ascites encephalopathy antibiotics 
antibiotics_specify steroids steroid_dose ptx ptx_dose other_tx  intervention alcohol_found fglucose creat 
bili_tot hemoglobin albumin 
 ;
	format steroids VARYN_. visit_date2 lab_date2 date9.;
run;

***************************************************************************************************************;

**************************************COMPLICATIONS AND STUDY EXIT*********************************************;
***************************************************************************************************************;
proc import out=COMPLICATIONS_N_STUDYEXIT
file="I:\Projects\AlcHepNet\InTeam Data\Data from Ana 2021-11-19\InTeam full database.xlsx"

dbms=excel replace;
sheet ="Complications&StudyExit";
/*GUESSINGROWS=2000;*/
run;

*death related variables are here
mortality_bin= alive
DEATH_DATE_NUM=dthdtc EXIT_DATE_NUM =eosoffdat
consent_date=rct_enrollrctdat ;
 
   data compnexit;
   set COMPLICATIONS_N_STUDYEXIT;
   if pt_type=1 then delete;
   if creatinine_units="umol_l" then max_creat_md_dl =(creatinine_umol_l_bl*0.0113);

dod2 =input(dod, date11.);
last_seen_alive_date2=input(last_seen_alive_date, anydtdte32.);
transplant_date2=input(transplant_date, anydtdte32.);

drop dod last_seen_alive_date transplant_date;

rename dod2= dthdtc last_seen_alive_date2=last_seen_alive_date transplant_date2=transplant_date;
   keep
	subject_id auth_site_id set_name visit_sort consent_date exit_date subject_status pt_type 
	other_complications 
	infection_1 infection_2 
	organism_type_1 gi_bleed infection_3 gi_bleed_type  pressors_count_1 infection_other_specify_3 
	encephalopathy_level sepsis_3  max_creat_md_dl 

	exit_reason pt_die dod death_main_reason death_cause_liver organ_fail sepsis_death
	massive_bleeding_death other_death transplant_date2 organ_fail_specify specify_other_deah  hyperglycemia other_reason 
last_seen_alive_date2
	sepsis_1 sepsis_2
infection_1
infection_2
infection_date_1
infection_date_2
organism_type_1
organism_type_2
infection_3
bacteriemia_2
infection_date_3
sbp_2
pneumonia_2
infection_other_2
infection_other_specify_2
bacteriemia_1
organism_type_3
sepsis_2
sbp_1
pneumonia_1
infection_other_1
bacteriemia_3
infection_other_specify_1
sbp_3
pneumonia_3
sepsis_1
infection_other_3
infection_other_specify_3
sepsis_3 dod2
;
format dod2 last_seen_alive_date2 transplant_date2 date9.;
   run;

***************************************************************************************************************;


*move some study exit variables to the baseline datase;
proc sort data= screening_n_baseline2 ; by subject_id visit_sort set_name; run;
proc sort data= compnexit ; by subject_id visit_sort set_name; run;

proc sql;
create table screening_n_baseline3 as
select s2.*, c.exit_date, c.exit_reason,c.pt_die,c.dthdtc,c.death_main_reason
	,c.death_cause_liver ,c.organ_fail ,c.sepsis_death ,c.massive_bleeding_death ,c.other_death ,
	c.transplant_date ,c.organ_fail_specify ,c.specify_other_deah ,c.hyperglycemia ,c.other_reason ,
	c.last_seen_alive_date
	,c.infection_1
,c.infection_2
,c.infection_date_1
,c.infection_date_2
,c.organism_type_1
,c.organism_type_2
,c.infection_3
,c.bacteriemia_2
,c.infection_date_3
,c.sbp_2
,c.pneumonia_2
,c.infection_other_2
,c.infection_other_specify_2
,c.bacteriemia_1
,c.organism_type_3
,c.sepsis_2
,c.sbp_1
,c.pneumonia_1
,c.infection_other_1
,c.bacteriemia_3
,c.infection_other_specify_1
,c.sbp_3
,c.pneumonia_3
,c.sepsis_1
,c.infection_other_3
,c.infection_other_specify_3
,c.sepsis_3
from screening_n_baseline2 s2
left join compnexit c on s2.subject_id = c.subject_id
where c.visit_sort=7;
quit;

data COMPLICATIONS_N_STUDYEXIT3;
set compnexit;

drop
	exit_date exit_reason pt_die dthdtc death_main_reason death_cause_liver organ_fail sepsis_death  
	massive_bleeding_death other_death transplant_date  organ_fail_specify specify_other_deah hyperglycemia  
	other_reason last_seen_alive_date consent_date subject_status ;
run;

proc sort data= visits_discharge2 ; by subject_id visit_sort set_name; run;
proc sort data= UNSCHEDULED2  ; by subject_id visit_sort set_name; run;
proc sort data= COMPLICATIONS_N_STUDYEXIT3 ; by subject_id visit_sort set_name; run;


***combine all visits data;
data all_inteam_data;
merge   visits_discharge2 UNSCHEDULED2 COMPLICATIONS_N_STUDYEXIT3;
by subject_id visit_sort set_name;
drop consent_date exit_date;
run;

*I will get the calculated variables from the short file;
proc import out=externalData
file="I:\Projects\AlcHepNet\InTeam Data\Data from Ana 2021-11-19\Data_InTeam_short version (323 patients).xlsx"

dbms=excel replace;
sheet ="Relapse_prediction_data_InTeam ";
/*GUESSINGROWS=20;*/
run;

data short;
set externalData;
if id eq . then delete;
rename id=subject_id DF=maddrey;
keep ID
	HE_BASELINE HE_BASELINE_CODE  BMI MELD DF LILLE D90_MORTALITY_BIN D90_MORTALITY_BIN_CODE
	ABSTINENCE_D30_CODE ABSTINENCE_D30_BIN ABSTINENCE_D30_DATE ABSTINENCE_D30_DATE_NUM
	RELAPSE_ANYTIME RELAPSE_ANYTIME_GRADE RELAPSE_DATE TIME_TO_RELAPSE 
	AUDIT_POINTS AUDIT_CAT AUDIT_CAT_CODE; 
run;

proc sort data=short;by subject_id; run;

data screening_n_baseline4;
merge screening_n_baseline3 (in=a) short(in=b);
by subject_id;
if biopsy=0 then biopsy=2;
run;


***********************************EXPORT TO FOLDER*************************************************;
*baseline and screening data ;
data output.it_screen_Baseline; 
retain study;
set screening_n_baseline4; 
/*if visit_sort=1 then redcap_event_name="day_0_arm_5";*/
study="inTeams";
run;

*visits data;
data output.it_visits;
retain study;
set all_inteam_data; 
study="inTeams";
run;

****************************************************************************************************;
 *****************END OF PROCESSING inTEAM DATA****************;



*
Message from Qing:
	I have attached the email with Dr. Bataller’s analysis description.
	The variables I am looking for are: 
	demo data (arms, age, gender, race, on steroid or not, enrollment date, death date, off study date),  
	labs/meld at each visits, 
	TLFB at each visits,
	complications at each visit (encephalopathy, jaundice, variceal hemorrhage, ascites, bacterial infections)
;

/*I'll use the final RCT datasets for some of this data*/
libname finalrct "I:\Projects\AlcHepNet\DataManagement\Datasets\Final\RCT";

data demog;
set finalrct.rct_subjects;
if rct_arm= 1 then steroids=1;
if rct_arm= 2 then delete;
rename rct_enrollrctdat =enrollrctdat calc_age=age calc_bmi = bmi height_cm= height;

keep
usubjid site eoscomplyn eosoffdat rct_eosreason rct_eosreasonoth rct_eosreason1
height_cm calc_bmi calc_age mh004dat days_on_study status ALIVE days_on_tx tx_status
rct_arm weight_kg deathrel dthdtc mh005 mh003b rct_eosreason eosoffdat eoscomplyn rct_meld_strata
ARM ethnic race brthdtc sex rct_enrollrctdat rct_enroll codp cods deathrel steroids alive
;
run;


data arm;
set demog;
keep usubjid arm;
run;


*bacterial infection is at discharge*;
data bacinf;

merge arm(in=a) inset.discharge (in=b);
by usubjid;
if a;
if redcap_event_name ^="day_0_arm_5" then delete;

if bacdx___1 =1 then Spbactper =  1 ; 
if bacdx___2 =1 then Pneumonia  =  1 ;
if bacdx___3 =1 then uti  =  1 ; 
if bacdx___4 =1 then CDI  =  1 ; 
if bacdx___5 =1 then bBloodsinf  =  1 ; 
if bacdx___6 =1 then Cholangitis  =  1;
if bacdx___7 =1 then Cellulitis   =  1; 

keep usubjid site redcap_event_name /*bacdx___1-bacdx___888 bacdxoth*/bacdxoth
Spbactper  Pneumonia    uti  CDI   bBloodsinf  Cholangitis  Cellulitis  ;
run;

data bacinf;
retain usubjid site redcap_event_name bacdxoth Spbactper Pneumonia uti CDI bBloodsinf 
	Cholangitis Cellulitis  bacdx___8 ;
set bacinf;
format Spbactper  Pneumonia    uti  CDI   bBloodsinf  Cholangitis  Cellulitis  VARYN_.;
run;


data hosp;
set inset.hospitalization (in=b);
if redcap_event_name ^="documentation_arm_5" then delete;
if rct_admrsn___4 = 0  then delete;
if rct_admrsn___4 = 1  then GI_bleed =1 ;
format gi_bleed VARYN_.;
keep usubjid site gi_bleed;
run;


data HEPEN ;
merge arm(in=a) inset.visit(in=b);
by usubjid;
if a;
if missing(hepenyn) then delete;
keep usubjid site redcap_event_name hepenyn;
run;

proc sort data=HEPEN  out=HEPEN(drop= redcap_event_name)  NODUPKEY;
   by usubjid;
run;


*******Longitudinal data*******;
data labs;
merge arm(in=a) inset.labs;
by usubjid;
if a;
/*drop labs_sourcesig labs_complete visitnd redcap_repeat_instrument redcap_repeat_instance labs_source;*/
keep usubjid ARM site redcap_event_name labsnd labdat  hemdat hemoglobin   hematocrit hematocritdat 
wbc  neutrophils lymphocytes   monocytes eosinophils  platelet mcv  coagdat  inr_symb inr pt pt_upper   chemdat  sodium 
 potassium   chloride  calcium   bicarbonate  glucose_type rglucose   fglucose   albumin bili_tot bili_dir_symb bili_dir 
 creat est_gfr  alt ast alkaline bun triglyceridend___999 triglyceride altx3 protein_tot;
run;


/*ascites is only at baseline*/
data ascites(keep=usubjid site redcap_event_name  ascyn) /*ascites is only at baseline*/
/*visit contains tlfb meld bmi lille*/
	 visit (keep=usubjid site redcap_event_name  weight height 
			meld bmi lille tlfbnd tlfbperson tlfbpersonoth tlfb30dyn tlfbnumd tlfbnumdd peskinjaund );
merge arm(in=a) inset.visit(in=b);
by usubjid;
if a;
if meld=999 then meld = .;
if ascyn ne . then output ascites; 
output visit;
run;

proc sort data=ascites (drop= redcap_event_name) out=ascites NODUPKEY;   by usubjid; run;


**get varices;
data varices;
set finalrct.rct_soc;
if endovaryn___1 =1 or endovaryn___2 =1 then varices =1;
if endovaryn___3 =1 then varices=0;
format varices VARYN_.;
keep usubjid site redcap_event_name /*endovaryn___1 endovaryn___2 endovaryn___3 */varices;
run;

*get maddrey;
data ahn_maddrey;
set finalrct.rct_liverscores;
keep usubjid redcap_event_name maddrey;
run;


*******MERGE BASELINE DATA WITH DEMOGRAPHIC**********;
data demog2;
merge demog(in=a) ascites(in=b)  HEPEN(in=c)  hosp(in=d)  bacinf(in=e) ;
by usubjid; if a;
drop redcap_event_name weight_kg mh003b mh005 rct_arm mh004dat days_on_study status ALIVE days_on_tx tx_status;
run;


**************MERGE LABS WITH VISIT*************;
proc sort data=labs; by usubjid redcap_event_name; ; run;
proc sort data=varices; by usubjid redcap_event_name; ; run;

DATA visitsData;
merge visit labs ahn_maddrey varices;
by usubjid redcap_event_name;
run;

*************OUTPUT AHN DATA************;
data output.Ahn_demographics;
retain study;
set demog2;
study="AHNPred    ";
run;

data output.ahn_visits;
retain study;
set visitsData;
study="AHNPred    ";

run;



***********************TREAT DATA******************************;

libname treat "I:\Projects\TREAT\FinalDatasets\TREAT001";
%include 'I:\Projects\TREAT\Data Management\sas\TREAT_formats.sas';

data treatenr;
retain study usubjid visitnum site STUDY_SITE ARMS BIRTH_DATE AGE_ON_STUDY CAL_AGE RACE race2 GENDER sex;
set treat.enrollment;
if arms="CASES";
visitnum=0;
study="TREAT";

*Sex is different too...;
if Gender ="M" then sex=1;
if Gender ="F" then sex=2;

*adjust race to match AHN race;
if race=1 then race2=1;
if race=2 then race2=2;
if race=3 then race2=3;
if race=5 then race2=4;
if race=7 then race2=6;
if race in(6,9) then race2=777;

rct_eosreason=OFFSTUDY_REASON;
if off_study_reason= 2 and offstudy_reason= . then rct_eosreason=5;
if OFF_STUDY_REASON = 14 and offstudy_reason= . then rct_eosreason=5;

if OFF_STUDY_REASON eq 10 then eoscomplyn = 1; else eoscomplyn =0;

format race2 race_all. sex sex_.;
drop race site; 
rename  race2=race cal_age =age ETHNICITY = ethnic birth_date=brthdtc
OFF_STUDYDATE=eosoffdat ON_STUDY_DATE=enrollrctdat DATE_OF_DEATH_IF_APPLICABLE_ =dthdtc heightcm=height;

keep

SITE  USUBJID ARMS BIRTH_DATE CAL_AGE 
 ETHNICITY  HEIGHTCM   ON_STUDY_DATE DATE_OF_DEATH_IF_APPLICABLE_ GFR 

/*GLUCOSE_RAND GLUCOSE_FAST  TOTAL_BILIRUBIN DIRECT_BILIRUBIN   CREATININE   ALT AST AST_FIND  ALKALINEPHOS   TOTAL_PROTEIN */
/* HEMOGLOBIN_DATE WBC WBC_UNITS  COAG_DATE INR PROTHROM PT_UPPERLIMIT   BINFECTION */


 DATE_OF_DEATH_IF_APPLICABLE_ DEATH_CAUSE1 DEATH_CAUSE2 DEATH_RELATEDTO 
 OFF_STUDYDATE  OFF_STUDY_REASON_EXPLAIN  
OFF_STUDY_DATE CURRENT_STATUS  LAST_VISIT_DATE visitnum study race2 sex rct_eosreason eoscomplyn;

/*vareiables that are not needed but might in the future */
/*
HOSP_ADMISSION_DATE HOSP_DISCHARGE_DATE HOSPITALIZED_ENROLMENT OFFSTUDY_REASON  OFF_STUDY_REASON OFFSTUDY_COMMENTS
OFFSTUDY_REASON_SPECIFY  BLOODCHEM_DATE GLUCOSE_RAND_FIND  TOTAL_BILIRUBIN_FIND  DIRECT_BILIRUBIN_FIND
GLUCOSE_FAST_FIND   ALBUMIN ALBUMIN_FIND  ALT_FIND  TOTAL_PROTEIN_FIND CREACTPROTEIN_FIND WBC_FIND  INR_FIND
 PROTHROM_FIND CREATININE_FIND GFR_FIND  ALKALINEPHOS_FIND CREACTPROTEIN_UNITS CREACTPROTEIN CREATININE_UNITS 
TOTAL_BILIRUBIN_UNITS OFF_TREATMENTDATE OFF_TREATMENT_REASON EXPIRED_DATE  
*/

run;

data subjs;
set treatenr;
keep usubjid arms;
run;


/*NOTE: waist is measured in CM in both AHN and TREAT*/
data treatvisits;
merge subjs (in=a) treat.visits(in=b);
by usubjid; if a;
rename meld_score =meld had_biopsy =biopsy SHENCEPHAL=HE SHENCEPHAL_date=he_date ALKALINEPHOS=alkaline
weightkg= weight  CHILDPUGH_SCORE=cps glucose_fast=fglucose varices=varyn ASCITES=ascyn PROTHROM=pt
CREATININE=creat
;
keep usubjid visitnum had_biopsy  VISIT_DATE

ascites ascites_date SHENCEPHAL SHENCEPHAL_DATE VARICES VARICES_DATE ANTIBIOTIC sm_steriods sm_pento
sm_same MELD_SCORE  CHILDPUGH_SCORE WEIGHTKG BMI
AUDITQ1-AUDITQ10
/*NIAAAQ1-NIAAAQ6*/
 HEMOGLOBIN  WBC PLATELET  mcv  inr  prothrom prothrom_find
GLUCOSE_RAND  glucose_fast ALBUMIN  TOTAL_BILIRUBIN  
 CREATININE  alt  ast  
tlfb_complete30 tlfb_totaldrinks2  TLFB_TOTALDRINKINGDAYS  TLFB_AVG_drinksDD ALKALINEPHOS pt_upperlimit
;
/*BINFHOSP binfothertxt DIRECT_BILIRUBIN  ALCPROGRAM */
run; 

data pred predns metpredns metprednsb;
set treat.conmeds;
if cm_med in("Prednisone" ,"Prednisolone","Methylpredisolone","Methylprednisolone",
"Methylprednisolone Sodium Succinate","Methyprednisolone" );
if cm_med="Prednisone" then do ;pred=1; output pred; end;
if cm_med="Prednisolone" then do predns=1; output predns; end;
if cm_med="Methylpredisolone" then; do ; metpredns=1; output metpredns; end;
if cm_med="Methylprednisolone" then do; metpredns=1; output metprednsb; end;
if cm_med="Methylprednisolone Sodium Succinate" then metpredns=1;
if cm_med="Methyprednisolone" then metpredns=1;


keep usubjid cm_med pred predns metpredns CM_FROM_DATE;
run;

proc sort data= pred(keep=usubjid pred) 	out=pred2 nodupkey; by usubjid; run;
proc sort data= predns(keep=usubjid predns) out=predns2 nodupkey; by usubjid; run;
proc sort data= metpredns(keep=usubjid metpredns) out=metpredns2 nodupkey; by usubjid; run;
	*last one not needed , they are all in the one above;
/*proc sort data= metprednsb(keep=usubjid metpredns) out=metprednsb2 nodupkey; by usubjid; run;*/


data treatcmmed;
merge pred2 predns2 metpredns2;
by usubjid;
format pred predns metpredns VARYN_.;
run;

*need to get ascites at baseline;
data asc;
set treat.visits;
if visitnum=1;
if ascites=2 then ascites=0;
rename ascites =ascyn;
format ascites ASCYN_39.;
keep usubjid ascites;
run;

proc sort data =asc nodupkey out=asc2; by usubjid; run;

/*and bmi at baseline*/
data treat_bmi_d1;
set treatvisits;
if visitnum = 1;
keep usubjid  bmi;
run;


proc sort data =treat_bmi_d1 nodupkey out=treat_bmi_d1; by usubjid; run;

data treatenr2;
merge subjs(in=a) treatenr(in=b) treatcmmed(in=c) asc2(in=d) treat_bmi_d1(in=e);
by usubjid; if a;
if pred =1 or predns=1 or  metpredns=1 then steroids =1; else steroids=0;
drop arms;
run;

**************OUTPUT TREAT DATA*********************;
data output.treat_demographics;
set treatenr2;
drop visitnum;
run;

data output.treat_visits;
set treatvisits;
study="TREAT";
run;
******************************************************************************



***Ill need to change some variables from inTeams dataset again, 
	in order to about messing up any code that Qing might already have done with the previous
	datasets, I will make them in a new one .. Ronny;

/*extrat height at baseline*/
data it_height;
set output.it_visits;
if set_name="Baseline (Day 0)";

rename ht_cm =height ;
keep subject_id set_name ht_cm;
run;

data it_steroids; 
set output.it_visits;
if steroids=1;
keep subject_id steroids;
run;

data it_ascites;
set output.it_visits;
if ascites ne . ;
keep subject_id set_name ascites;
run;

proc sort data=it_steroids out=it_steroids2 nodupkey; by subject_id; run;

proc sort data=it_ascites out=it_ascites2 nodupkey; by subject_id; run;

data it_ascites3;
set it_ascites2; if ascites=1 then ascyn=0;else ascyn=1;
format ascyn ascyn_39.;
keep subject_id ascyn;
run;

data ITd;
merge  output.it_screen_baseline it_height it_steroids2 it_ascites3;
by subject_id;
if ethnicity  ="not_hispanic" then ethnic = 2;
if ethnicity  ="hispanic" then ethnic = 1;
if ethnicity  ="" then ethnic = 777;

if exit_reason=1 then eoscomplyn=1; *complete study;

/*exit_reason -> rct_eosreason*/
if exit_reason=4  then do ; rct_eosreason= 8; 	eoscomplyn=0; end; *death;
if exit_reason=2  then do ; rct_eosreason= 5; 	eoscomplyn=0; end;  *Lost to follow up;
if exit_reason=3  then do ; rct_eosreason= 1; 	eoscomplyn=0; end;  *Withdrew consent;
if exit_reason=5  then do ; rct_eosreason= 11;	eoscomplyn=0; end;  *Liver transplant;
if exit_reason=6  then do ; rct_eosreason= 888; eoscomplyn=0; end;  *Other reasons;

if HE_BASELINE_CODE > 1 then HE_BASELINE_CODE=1; else HE_BASELINE_CODE=0 ;

rename 
/*audit_1 = auditq1 audit_2= auditq2 audit_3 =auditq3 audit_4 =auditq4 audit_5 =auditq5*/
/*audit_6= auditq6 audit_7 =auditq7 audit_8 =auditq8 audit_9 =auditq9 audit_10= auditq10*/
race2=race start_date=enrollrctdat exit_date=eosoffdat HE_BASELINE_CODE =hepenyn
;



drop ethnicity exit_reason it_site auth_site_id visit_sort set_name registration_date consent_date year_inclusion 
 subject_status  birth_year  days_tx  pred_cum  pendo_cum hep_b hep_b_antigen hep_b_dna hep_c hep_rna 
race_ctrl fibrosis_stage steatosis mallory_bodies bilirubinostasis ballooning giant_mitochondria 
pmn_infiltration inflammatory_grade other_findings other_findings_txt biopsy_date pt_die dthdtc 
death_main_reason death_cause_liver organ_fail sepsis_death massive_bleeding_death other_death 
   last_seen_alive_date infection_1 infection_2 infection_3 bacteriemia_2  pneumonia_2  
sepsis_2 pneumonia_1 infection_other_1 bacteriemia_3 infection_other_specify_1  pneumonia_3 sepsis_1
infection_other_3 infection_other_specify_3 sepsis_3 HE_BASELINE 
lobular_fibrosis pericellular_fibrosis transplant_date organ_fail_specify specify_other_deah other_reason
infection_date_1 infection_date_2 organism_type_1 organism_type_2 infection_date_3 sbp_2 infection_other_2
infection_other_specify_2 organism_type_3 sbp_1 sbp_3

 ABSTINENCE_D30_CODE ABSTINENCE_D30_BIN pred_tx;
run;



/*variables that are on baseline that might be better at visits dataset*/
data it_from_bas_to_vis;
set output.it_screen_baseline;
rename audit_1 = auditq1 audit_2= auditq2 audit_3 =auditq3 audit_4 =auditq4 audit_5 =auditq5
audit_6= auditq6 audit_7 =auditq7 audit_8 =auditq8 audit_9 =auditq9 audit_10= auditq10;


keep subject_id visit_sort audit_1 audit_2 audit_3  audit_4  audit_5 audit_6 audit_7 audit_8 audit_9 audit_10
biopsy meld df lille audit_points audit_cat audit_cat_code;
run;


data it_visits;
merge output.it_visits it_from_bas_to_vis;
by subject_id visit_sort;

pt2= input(pt,8.);

triglyceride2=input(triglyceride,8.);
potassium2=input(potassium, 8.);



drop potassium triglyceride pt;
rename ht_cm =height pt2=pt potassium2=potassium triglyceride2=triglyceride
alk_phos=alkaline;



run;



********************MERGING ALL DATA*****************;
proc sort data=output.ahn_demographics ; by study usubjid; run;
proc sort data=output.treat_demographics; ; by study usubjid; run;
proc sort data=output.it_screen_baseline; ; by study subject_id; run;

data a;
merge output.ahn_demographics output.treat_demographics;
by study usubjid;
run;

data allbaseline;
retain study subject_id2 visitnum;
length subject_id2 $8.;
merge a itd;
by study;
if study="TREAT" then subject_id2=cats("TRT",usubjid);
if study="inTeams" then subject_id2=cats("InT",subject_id);
if study="AHNPred    " then subject_id2=cats("AHN",usubjid);


/*drop subject_status pred_cum pendo_cum*/
/*hep_b hep_b_antigen hep_b_dna hep_c hep_rna race_ctrl hematocritdat off_study_date current_status*/
/*last_visit_date it_sire subject_id auth_site_id visit_sort set_name registration_date consent_date year_inclusion*/
/*subject_status birth_year pred_cum pendo_cum*/
/*cause of death*/
drop
codp cods deathrel death_cause1  DEATH_CAUSE2 DEATH_RELATEDTO 
pred predns metpredns pento_tx hyperglycemia

OFF_STUDY_REASON_EXPLAIN OFF_STUDY_DATE CURRENT_STATUS rct_eosreason rct_eosreason1 rct_eosreasonoth
site admit_date subject_id pt_type prior_tx D90_MORTALITY_BIN D90_MORTALITY_BIN_CODE ABSTINENCE_D30_DATE 
ABSTINENCE_D30_DATE_NUM RELAPSE_ANYTIME RELAPSE_ANYTIME_GRADE RELAPSE_DATE TIME_TO_RELAPSE
biopsy  meld df lille audit_points audit_cat audit_cat_code bacteriemia_1 audit_1-audit_10
;
run;


data allbaseline;
retain study subject_id2 usubjid age brthdtc sex race ethnic ARM rct_enroll 
rct_meld_strata enrollrctdat eoscomplyn eosoffdat dthdtc LAST_VISIT_DATE
 steroids ascyn hepenyn height BMI
GI_bleed bacdxoth Spbactper Pneumonia uti CDI bBloodsinf Cholangitis Cellulitis ;

set allbaseline;
run;

data all_visits;
retain study subject_id2 visitnum2;
length subject_id2 $8.;
merge output.ahn_visits output.treat_visits it_visits ;
by study;
if study="TREAT" then subject_id2=cats("TRT",usubjid);
if study="inTeams" then subject_id2=cats("InT",subject_id);
if study="AHNPred    " then subject_id2=cats("AHN",usubjid);

if  redcap_event_name="screening_visit_arm_5" then visitnum2 =0;
if  redcap_event_name="day_0_arm_5" then visitnum2 =1;
if  redcap_event_name="day_3_arm_5" then visitnum2 =2;
if  redcap_event_name="day_7_arm_5" then visitnum2 =3;
if  redcap_event_name="day_14_arm_5" then visitnum2 =4;
if  redcap_event_name="day_28_arm_5" then visitnum2 =.;**possible 4;***AHN doesnt have day 30;
if  redcap_event_name="day_60_arm_5" then visitnum2 =6;
if  redcap_event_name="day_90_arm_5" then visitnum2 =7;
if  redcap_event_name="day_180_arm_5" then visitnum2 =8;

if visitnum=0 then visitnum2=0;
if visitnum=1 then visitnum2=1;
if visitnum=2 then visitnum2=2;
if visitnum=3 then visitnum2=3;
if visitnum=4 then visitnum2=5;
**treat doesnt have 60 days(3 months) fu;
if visitnum=5 then visitnum2=8;
if visitnum=6 then visitnum2=9;
if visitnum=50 then visitnum2=50;
if visitnum=98 then visitnum2=98;
if visitnum=99 then visitnum2=99;

if visit_sort = 1 then visitnum2=1;
if visit_sort = 2 then visitnum2=3;
if visit_sort = 3 then visitnum2=.;
if visit_sort = 4 then visitnum2=5;
if visit_sort = 5 then visitnum2=6;
if visit_sort = 6 then visitnum2=7;
if visit_sort = 7 then visitnum2=50;
if visit_sort = 9 then visitnum2=98;

chol_tot2= input(chol_tot,5.);
est_gfr2= input(est_gfr,5.);

drop site  tlfbperson labsnd labdat hemdat chemdat triglyceridend___999

subject_status pred_cum pendo_cum
hep_b hep_b_antigen hep_b_dna hep_c hep_rna race_ctrl hematocritdat off_study_date current_status
last_visit_date it_sire subject_id auth_site_id  registration_date consent_date year_inclusion
subject_status birth_year pred_cum pendo_cum pred predns metpredns
usubjid visitnum redcap_event_name set_name visit_sort visit_date lab_date pt_type albumin_value_g_dl
bilirubin_value_mg_dl creatinine_value_mg_dl glucose_value_mg_dl antibiotics_specify steroid_dose
other_tx intervention heart_rate oxygen_sat wt_kg height encephalopathy antibiotics triglycerides_value_mg_dl
systolic diastolic other_complications
alcohol_found prothrombin_time 
infection_1 infection_2 infection_date_1 infection_date_2 organism_type_1 organism_type_2
 ptx  gi_bleed infection_3 gi_bleed_type 
bacteriemia_2 infection_date_3 sbp_2 pneumonia_2 infection_other_2 infection_other_specify_2 bacteriemia_1 
organism_type_3 sepsis_2 sbp_1 pneumonia_1 infection_other_1 bacteriemia_3 infection_other_specify_1 
sbp_3 pneumonia_3 sepsis_1 infection_other_3 pressors_count_1 infection_other_specify_3 
encephalopathy_level sepsis_3 max_creat_md_dl arm chol_tot est_gfr
;

rename chol_tot2=chol_tot est_gfr2= est_gfr;

format visitnum2 newvisits.;
run;



*****************Merge AHNOBS visits with the rest of the visits**************;


libname finalobs "I:\Projects\AlcHepNet\DataManagement\Datasets\Final\OBS";

data obsdemog;
retain study subject_id2 visitnum;
set finalobs.obs_subjects;
if arm = 1;
study="AHNOBS    ";
subject_id2=cats("AHNOBS",usubjid);
rename obs_enrolldat =enrollrctdat calc_age=age calc_bmi = bmi height_cm= height;

keep study subject_id2 visitnum ARM
usubjid eoscomplyn eosoffdat obs_eosreason obs_eosreasonoth obs_eosreason1
height_cm calc_bmi calc_age  days_on_study s
 weight_kg  dthdtc eosoffdat eoscomplyn 
ARM ethnic race brthdtc sex  steroids alive obs_enrolldat
;

/*mh004dat status ALIVE days_on_tx tx_status alive mh005 mh003b deathrel codp cods deathrel*/
run;

*need to get ascites hepen and varices at baseline;
data obsmedinf;
set finalobs.obs_medinfo;
if redcap_event_name in("week_0_arm_2");
keep usubjid hepenyn varyn ascyn ;
run;


data obs_baseline;
merge obsdemog obsmedinf;
by usubjid;
run;



data obslabs;
set finalobs.obs_labs;
study="AHNOBS    ";
if redcap_event_name in("week_0_arm_2", "week_12_arm_2" ,"week_24_arm_2" ,"week_4_arm_2");
subject_id2=cats("AHN",usubjid);
rename PROTHROM = pt glucose_fast =fglucose total_bilirubin= bili_tot CREATININE=creat;

drop chol_hdl_norm chol_ldl_norm chol_tot_norm triglyceride_norm protein_tot_norm alkaline_norm
ast_norm alt_norm _norm creat_norm bili_dir_norm bili_tot_norm albumin_norm rglucose_norm
pt_norm inr_norm mcv_norm platelet_norm wbc_norm hemoglobin_norm labdat hemdat hemdatoth chemdat
chemdatoth rglucosedat fglucose_norm albumindat bili_totdat bili_dirdat creatdat est_gfrdat altdat
astdat alkalinedat protein_totdat lipiddat lipiddatoth triglyceridedat chol_totdat est_gfr_symb est_gfr_norm
hcv_logdat  hcv_log hcv_absdat hcv_abs hcv_antibodydat hcv_antibody hbvdat hbv hivdat hiv labsnd plateletdat
mcvdat coagnd___999 chol_ldl chol_ldldat chol_hdl chol_hdldat coagnd___999;
run; 

/*need to get meld , lille ect*/
data obslivers;
set finalobs.obs_liverscores;
if redcap_event_name in("week_0_arm_2", "week_12_arm_2" ,"week_24_arm_2" ,"week_4_arm_2");
subject_id2=cats("AHN",usubjid);
study="AHNOBS    ";
keep usubjid redcap_event_name meld cps tlfbnd tlfb30dyn tlfbnumd tlfbnumdd subject_id2 study;
run;

data obsBMI;
set finalobs.OBS_VITALS;
if redcap_event_name in("week_0_arm_2", "week_12_arm_2" ,"week_24_arm_2" ,"week_4_arm_2");
subject_id2=cats("AHN",usubjid);
study="AHNOBS    ";
keep subject_id2 usubjid weight bmi study;
run;


data obs_visits;
merge obslabs obslivers obsbmi;
by subject_id2;
run;


proc sort data=all_visits; by study subject_id2; run;

data all_visits2;
merge all_visits obs_visits;
by study;
if usubjid=81096 then delete;
drop usubjid site child_pugh res_rate chol_tot;
run;


proc sort data=allbaseline; by study subject_id2; run;
proc sort data=obs_baseline; by subject_id2; run;

data allbaseline2;
merge allbaseline obs_baseline;
by study;
if usubjid = 81096 then delete;
drop GI_bleed bacdxoth Spbactper Pneumonia uti CDI bBloodsinf Cholangitis Cellulitis 
obs_eosreason obs_eosreason1 weight_kg days_on_study ALIVE ;
run;

/*proc sql;*/
/*select * from sashelp.vcolumn where lowcase(label) like "%maddrey%"*/
/*and libname="FINALOBS";*/
/*quit;*/


***ADITIONAL: Need to add AHN OBS data too;

*****OUTPUT MERGED DATA******;
/*demo (study group, site, study id,  age, gender, race, bmi, enrollment date, off study date, death date, on steroid yes/no,);*/
/*Labs and meld (meld, lille, fglucose, albumin, bili_total, create,  alt,  ast , alkaline,  protein_tot,  hemoglobin,  wbc, platelet, mcv , inr, pt and MDF ) */


data output.All_demographics;set allbaseline2;run;
data output.all_visits;;set all_visits2;run;



