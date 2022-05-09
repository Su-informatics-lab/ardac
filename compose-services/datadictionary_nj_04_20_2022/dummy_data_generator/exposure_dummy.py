import csv
import random
import scipy.stats as stats
#from tqdm import tqdm

file_in = ""
follow_up_num = 10

num_recording = follow_up_num









with open('/Users/nanxinjin/Downloads/submission_exposure_template_dummy.tsv','w') as out_file:
	tsv_writer = csv.writer(out_file, delimiter='\t')
	#print([data_type, project_id, submitter_id,cases_submitter_id, days_to_follow_up, bmi, cdc_hiv_risk_factors, comorbidity, height, procedures_performed, risk_factor, visit_day, weight])
	tsv_writer.writerow(["*type", "project_id", "*submitter_id","follow_ups.submitter_id", "ALC_LIFETIME_IND", "BEG_ALC_USE_AGE", "TM_UOM_TXT_NM", "alc_reg_use_len", "alcohol_drinks_per_day", "alcohol_history", "alcohol_intensity", "intravenous_drug_use"])
	for i in range(num_recording):
		data_type = "exposure"
		project_id = "program1-v0"

		index = i + 1
		submitter_id = "exposure_" + str(index)

		follow_up_submitter_id = "follow_up_" + str(index)

		ALC_LIFETIME_IND = random.choice(["Yes", "Unknown", "No"])

		BEG_ALC_USE_AGE = str(random.randint(1,80))

		TM_UOM_TXT_NM = random.choice(["Days", "Don't Know", "Months", "Refused", "Unknown", "Weeks", "Years"])

		alc_reg_use_len = str(random.randint(0,24))

		alcohol_drinks_per_day = str(random.randint(0,10))

		alcohol_history = random.choice(["No", "Yes", "Not Reported", "Unknown"])

		alcohol_intensity = random.choice(["Drink", "Heavy Drinker", "Lifelong- Non-Drinker", "Non-Drinker", "Not Reported", "Occasional Drinker", "Unknown"])

		intravenous_drug_use = random.choice(["Yes", "Unknown", "No"])

		print([data_type, project_id, submitter_id,follow_up_submitter_id, ALC_LIFETIME_IND, BEG_ALC_USE_AGE, TM_UOM_TXT_NM, alc_reg_use_len, alcohol_drinks_per_day, alcohol_history, alcohol_intensity, intravenous_drug_use])
		tsv_writer.writerow([data_type, project_id, submitter_id,follow_up_submitter_id, ALC_LIFETIME_IND, BEG_ALC_USE_AGE, TM_UOM_TXT_NM, alc_reg_use_len, alcohol_drinks_per_day, alcohol_history, alcohol_intensity, intravenous_drug_use])
