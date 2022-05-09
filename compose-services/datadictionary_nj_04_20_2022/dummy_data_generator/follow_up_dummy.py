import csv
import random
import scipy.stats as stats
#from tqdm import tqdm

file_in = ""
num_recording = 400









with open('20220420_nj_dummy_data/20220420_follow_up_dummy_nj.tsv','w') as out_file:
	tsv_writer = csv.writer(out_file, delimiter='\t')
	#print([data_type, project_id, submitter_id,cases_submitter_id, days_to_follow_up, bmi, cdc_hiv_risk_factors, comorbidity, height, procedures_performed, risk_factor, visit_day, weight])
	tsv_writer.writerow(["*type", "project_id", "*submitter_id","cases.submitter_id", "*days_to_follow_up", "bmi", "cdc_hiv_risk_factors", "comorbidity", "height", "procedures_performed", "risk_factor", "*visit_day", "weight"])
	for i in range(num_recording):
		data_type = "follow_up"
		project_id = "ardac-dev_v0"

		index = i + 1
		submitter_id = "follow_up_" + str(index)


		#generate pat_id for obs and rct patients
		if i < 200:
			cases_submitter_id = "pat_" + str(index)
			days_to_follow_up = "0"
		elif i < 250:
			cases_submitter_id = "pat_" + str(random.randint(1,100))
			days_to_follow_up = random.choice(["28", "60", "90"])
		elif i < 260:
			cases_submitter_id = "pat_" + str(index-150)
			days_to_follow_up = "28"
		elif i < 270:
			cases_submitter_id = "pat_" + str(index-160)
			days_to_follow_up = "60"
		elif i < 280:
			cases_submitter_id = "pat_" + str(index-170)
			days_to_follow_up = "90"
		elif i < 290:
			cases_submitter_id = "pat_" + str(index-130)
			days_to_follow_up = "28"
		elif i < 300:
			cases_submitter_id = "pat_" + str(index-140)
			days_to_follow_up = "60"
		elif i < 310:
			cases_submitter_id = "pat_" + str(index-150)
			days_to_follow_up = "90"
		elif i < 360:
			cases_submitter_id = "pat_" + str(random.randint(111,150))
			days_to_follow_up = random.choice(["28", "60", "90"])
		elif i < 400:
			cases_submitter_id = "pat_" + str(random.randint(151,200))
			days_to_follow_up = random.choice(["28", "60", "90"])
		

		


		

# bmi_mean = 24.4
# bmi_std = 7.1
		bmi = str(random.randint(18,30))
		cdc_hiv_risk_factors = random.choice(["Hemophiliac", "Heterosexual Contact", "Homosexual Contact", "Intravenous Drug User", "None", "Not Reported", "Transfusion Recipient", "Unknown"])
		comorbidity = random.choice(["Anemia", "Blood Clots", "Cancer", "Dermatomyosis", "Eczema"])
		height = str(random.randint(100,190))
		procedures_performed = random.choice(["Colonoscopy", "Endoscopy", "Unknown", "Not Reported"])
		risk_factor = random.choice(["Allergy, Ant", "Hemochromatosis", "Malaria", "Seizure"])
		visit_day = days_to_follow_up
		weight = str(random.randint(30,120))
		print([data_type, project_id, submitter_id,cases_submitter_id, days_to_follow_up, bmi, cdc_hiv_risk_factors, comorbidity, height, procedures_performed, risk_factor, visit_day, weight])
		tsv_writer.writerow([data_type, project_id, submitter_id,cases_submitter_id, days_to_follow_up, bmi, cdc_hiv_risk_factors, comorbidity, height, procedures_performed, risk_factor, visit_day, weight])
