import sqlite3
import json
from datetime import datetime

# ========================== extraction of multiqc data ================================
def descrambler(path):
    # data prep
    with open(path) as json_data:
        data = json.load(json_data)
    (header, general_multiqc, report_stats, project_id_data, vcf_stats) = poach(data) #separates json into chunks that will be used
    (run, instrument, flowcell, seqtype, date) = descramble_header(header, data) #extracts header data

    #extracts metrics per project ID
    project_dict = descramble_projects(project_id_data)
    for id in project_dict.keys():
        (avgDepth, avgDup, avgQ30, avgYield, numSamples, sumBases, avgVCFDepth) = descramble_metrics(id, project_dict, general_multiqc, report_stats, vcf_stats)
        # data entry prep and check
        entry_id = id + run
        runData = [entry_id, id, run, instrument, flowcell, seqtype, date, avgDepth, avgDup, avgQ30, avgYield, numSamples, sumBases, avgVCFDepth]
        context(runData)
        check(runData)

def poach(data):
    header = data['config_report_header_info'] #contains metadata
    general_multiqc = data['report_saved_raw_data']['multiqc_general_stats'] #contains metrics
    report_stats = data['report_general_stats_data'][4] #used for number of bases
    project_id_data = data['report_general_stats_data'][0] #contains project ids
    vcf_stats = data['report_general_stats_data'][5] #contains avg depth for vcf files

    return [header, general_multiqc, report_stats, project_id_data, vcf_stats]

def descramble_header(header, data):
    run = header[0]['Run']
    instrument = header[1]['Instrument']
    flowcell = header[2]['Flowcell']
    seqtype = header[3]['Seqtype']
    pathName = data['config_analysis_dir']
    date = (((pathName[0].split('/'))[-1]).split('_'))[0]
    date = datetime.strptime(date, '%y%m%d')
    date = date.date()
    return [run, instrument, flowcell, seqtype, date]

# divides run into projects
def descramble_projects(project_id_data):
    project_dict = {}
    
    for sample in project_id_data:
        project = project_id_data[sample]["Project"]

        if project not in project_dict.keys():
            project_dict[project] = [sample]
        else:
            project_dict[project].append(sample)
    return project_dict

# extracts metrics per project id
def descramble_metrics(id, project_dict, general_multiqc, report_stats, vcf_stats):
    numSamples = len(project_dict[id])

    sumBases = descramble_sumBases(id, project_dict, report_stats)
    avgDepth = descramble_avgDepth(id, project_dict, general_multiqc, numSamples)
    avgYield = descramble_avgYield(id, project_dict, general_multiqc, numSamples)
    avgQ30 = descramble_avgQ30(id, project_dict, general_multiqc, numSamples)
    avgDup = descramble_avgDup(id, project_dict, general_multiqc, numSamples)
    avgVCFDepth = descramble_avgVCFDepth(id, project_dict, vcf_stats, numSamples)

    return [avgDepth, avgDup, avgQ30, avgYield, numSamples, sumBases, avgVCFDepth]


# ==== Metric calculations ====

# prevents division by 0
def check0(sumMetric, numSamples):
    if numSamples >0:
        avgMetric = round(sumMetric/numSamples, 2)
    else:
        avgMetric = None
    return avgMetric

# calculates average depth
def descramble_avgDepth(id, project_dict, general_multiqc, numSamples):
    sumDepth = 0
    for sample in project_dict[id]:
        if sample in general_multiqc.keys():
            sumDepth += general_multiqc[sample]["Alignment Metrics_mqc-generalstats-alignment_metrics-MeanCoverage"]
        else:
            numSamples -= 1
    avgDepth = check0(sumDepth, numSamples)
    return avgDepth

def descramble_avgYield(id, project_dict, general_multiqc, numSamples):
    sumYield = 0
    for sample in project_dict[id]:
        if sample in general_multiqc.keys():
            sumYield += general_multiqc[sample]["FastP_mqc-generalstats-fastp-yield"]
        else:
            numSamples -= 1
    avgYield = check0(sumYield, numSamples)
    return avgYield

def descramble_avgQ30(id, project_dict, general_multiqc, numSamples):
    sumQ30 = 0
    for sample in project_dict[id]:
        if sample in general_multiqc.keys():
            sumQ30 += general_multiqc[sample]["FastP_mqc-generalstats-fastp-q30_rate"]
        else:
            numSamples -= 1
    avgQ30 = check0(sumQ30, numSamples)
    return avgQ30

def descramble_avgDup(id, project_dict, general_multiqc, numSamples):
    sumDup = 0
    for sample in project_dict[id]:
        if sample in general_multiqc.keys():
            sumDup += general_multiqc[sample]["FastP_mqc-generalstats-fastp-Duplication"]
        else:
            numSamples -= 1
    avgDup = check0(sumDup, numSamples)
    return avgDup

def descramble_avgVCFDepth(id, project_dict, vcf_stats, numSamples):
    sumVCFDepth = 0
    for sample in project_dict[id]:
        if sample in vcf_stats.keys():
            sumVCFDepth += vcf_stats[sample]["AVG_DP"]
        else:
            numSamples -= 1
    avgVCFDepth = check0(sumVCFDepth, numSamples)
    return avgVCFDepth

def descramble_sumBases(id, project_dict, report_stats):
    sumBases = 0
    for sample in project_dict[id]:
        if sample in report_stats.keys():
            sumBases += report_stats[sample]["TotalNbCoveredBases"]
        else:
            pass

    return sumBases


# =============================== Checks and printouts ========================================

# prints out data extracted
def context(runData):
    print("\n=====  data received: =====")
    print("\n entry id: ", runData[0], "\n project id: ", runData[1], "\n name of run: ", runData[2], "\n instrument: ", runData[3], \
          "\n flowcell: ", runData[4], "\n sequencing type: ", runData[5], "\n sequencing date: ", runData[6], \
          "\n average depth: ", runData[7], "\n average q30: ", runData[8], "\n average yield :", runData[9], \
          "\n average duplication rate :", runData[10], "\n total number of samples: ", runData[11], \
          "\n total number of bases sequenced: ", runData[12], "\n average sequencing depth at sites in VCF file: ", runData[13])

# Checks if a run is already in database and triggers actions
def check(runData):
    try:
        results = get(runData)
        if len(results) > 0:
            print("\nAn entry in the database already has this run name. Current entry in database: \n", results, \
                  "\nEntry will be replaced with new data: ")
            replace(runData) 
            newResults = get(runData)
            print("", newResults)
        else:
            print("\nThe run will be added to the database")
            add(runData)
    except sqlite3.Error as salmonella:
        print (salmonella)

# =============================== Database operations =========================================

# Displays entry
def get(runData):
    try: 
        entry_id = runData[0]
        con = sqlite3.connect('runData.db') 
        check = con.cursor().execute("SELECT * FROM runs WHERE entry_id = ?;", [entry_id])
        results = check.fetchall()
        con.close()
        return results
    except sqlite3.Error as salmonella:
        print (salmonella)

# Adds run results into database
def add(runData):
    try:
        con = sqlite3.connect('runData.db')
        con.cursor().execute("INSERT INTO runs \
                             (entry_id, project_id, run, instrument, flowcell, seqtype, seqDate, avgDepth, avgDup, avgQ30, avgYield, numSamples, sumBases, avgVCFDepth) \
                             values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", runData)
        con.commit()
        con.close()
    except sqlite3.Error as salmonella:
        print(salmonella)

# Deletes run from database
def delete(runData):
    entry_id = runData[0]
    try:
        con = sqlite3.connect('runData.db')
        con.cursor().execute("DELETE FROM runs WHERE entry_id=?", [entry_id])
        con.commit()
        con.close()
    except sqlite3.Error as salmonella:
        print (salmonella)

# Replaces a run that's already in the database
def replace(runData):
    try:
        delete(runData)
        add(runData)
    except sqlite3.Error as salmonella:
        print (salmonella)
