import csv
import random
import scipy.stats as stats
#from tqdm import tqdm

file_in = ""

obs_number = 100
arm_number_intervention = 50
arm_number_control = 50
arm_counter = 0

counter = 0

num_recording = obs_number + arm_number_intervention + arm_number_control





with open('20220420_nj_dummy_data/20220420_case_dummy_nj.tsv','w') as out_file:
	tsv_writer = csv.writer(out_file, delimiter='\t')
	#print([data_type, project_id, submitter_id,cases_submitter_id, days_to_follow_up, bmi, cdc_hiv_risk_factors, comorbidity, height, procedures_performed, risk_factor, visit_day, weight])
	tsv_writer.writerow(["*type", "project_id", "*submitter_id", "*studies.submitter_id", "actarm", "ah_hosp", "ah_hosp_num", "bari_surgery", "cohort", "consent_type", "days_to_consent", "index_date", "study_site"])
	for i in range(num_recording):
		data_type = "case"
		project_id = "ardac-dev_v0"

		index = i + 1
		submitter_id = "pat_" + str(index)

		#studies.submitter_id
		if counter < obs_number:
			studies_submitter_id = "obs_v0"
			counter += 1
		elif counter < num_recording:
			studies_submitter_id = "rct_v0"

		#actarm and cohort
		if studies_submitter_id == "obs_v0":
			actarm = ""
			cohort = random.choice(["Heavy Drinker with Alcoholic Hepatits", "Heavy Drinker without Alcoholic Hepatits", "Healthy Donor"])
		elif studies_submitter_id == "rct_v0":
			if arm_counter < arm_number_intervention:
				actarm = "Intervention"
				cohort = ""
				arm_counter += 1
			elif arm_counter < arm_number_intervention + arm_number_control:
				actarm = "Control"
				cohort = ""
				arm_counter += 1

		ah_hosp = ""
		ah_hosp_num = ""
		bari_surgery = ""
		consent_type = "Informed Consent"
		days_to_consent = "0"
		index_date = "Study Enrollment"


		study_site = random.choice(["Cleveland Clinic",
									"Indiana University",
									"University of Louisville",
									"University of Massachusetts",
									"Beth Israel Deaconess Medical Center",
									"Virginia Commonwealth University",
									"University of Pittsburgh",
									"Mayo Clinic Rochester",
									"University of Texas Southwest"])

		print([data_type, project_id, submitter_id, studies_submitter_id, actarm, ah_hosp, ah_hosp_num, bari_surgery, cohort, consent_type, days_to_consent, index_date, study_site])
		tsv_writer.writerow([data_type, project_id, submitter_id, studies_submitter_id, actarm, ah_hosp, ah_hosp_num, bari_surgery, cohort, consent_type, days_to_consent, index_date, study_site])
