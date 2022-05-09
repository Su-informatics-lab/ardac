import csv
import random
#import scipy.stats as stats
#from numpy import np
#from tqdm import tqdm


#(molecular_test) many to one (follow_up)
file_in = ""
follow_up_num = 10

num_recording = 400


with open('20220420_nj_dummy_data/20220420_molecular_test_dummy_nj.tsv','w') as out_file:
	tsv_writer = csv.writer(out_file, delimiter='\t')
	tsv_writer.writerow(["*type", "project_id", "*submitter_id","*follow_ups.submitter_id", "*gene_symbol", "*molecular_analysis_method", "*test_result", "blood_test_normal_range_lower", "blood_test_normal_range_upper", "days_to_test", "laboratory_test", "test_value"])
	for i in range(num_recording):
		data_type = "molecular_test"
		project_id = "ardac-dev_v0"

		index = i + 1
		submitter_id = "molecular_test_" + str(index)

		#follow_up_index = str(random.randint(1,follow_up_num))
		follow_up_submitter_id = "follow_up_" + str(index)

		gene_symbol = random.choice(["ACVR2A", "AFF1", "AFF3", "AFF4"])

		molecular_analysis_method = random.choice(["Comparative Genomic Hybridization", "Cytogenetics, NOS", "FISH", "Flow Cytometry", "IHC", "Immunofluorescence", "ISH", "Karyotype", "Microarray", "Microsatellite Analysis", "Nuclear Staining", "Other", "PCR", "RNA Sequencing", "RT-PCR", "Sequencing, NOS", "Southern Blotting", "Targeted Sequencing", "WGS", "WXS", "Unknown", "Not Reported"])

		test_result = random.choice(["Abnormal, NOS", "Copy Number Reported", "Equivocal", "High", "Intermediate", "Loss of Expression", "Low", "Negative", "Normal", "Overexpressed", "Positive", "Test Value Reported", "Unknown", "Not Reported"])

		blood_test_normal_range_lower = str(random.randint(0,10))

		blood_test_normal_range_upper = str(random.randint(90,100))

		days_to_test = str(random.randint(1,365))

		#laboratory_test = random.choice(["ALT", "AST", "Creatinine", "Estimated GFR", "INR"])
		laboratory_test = random.choice(["Estimated GFR"])

		if 251<= index <=260 or 281 <= index <= 290:
			test_value = str(random.randint(30, 59))
		elif 261<= index <=270 or 291 <= index <= 300:
			test_value = str(random.randint(15, 29))
		elif 271<= index <=280 or 301 <= index <= 310:
			test_value = str(random.randint(1, 15))
		else:
			test_value = str(random.randint(85, 120))

		print([data_type, project_id, submitter_id,follow_up_submitter_id, gene_symbol, molecular_analysis_method, test_result, blood_test_normal_range_lower, blood_test_normal_range_upper, days_to_test, laboratory_test, test_value])
		tsv_writer.writerow([data_type, project_id, submitter_id,follow_up_submitter_id, gene_symbol, molecular_analysis_method, test_result, blood_test_normal_range_lower, blood_test_normal_range_upper, days_to_test, laboratory_test, test_value])
