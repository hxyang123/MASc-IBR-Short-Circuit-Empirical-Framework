import os
import re
import pandas as pd
import numpy as np

# =========================
# USER SETTINGS
# =========================
DATA_FOLDER = "../PSCAD_auto_results/"     # <- CHANGE THIS
OUTPUT_FILE = "../PSCAD_auto_summary/auto_results_summary.csv"
is_V_drop = 1

# =========================
# HELPERS
# =========================
def extract_params(filename):
    """
    Extract P, Q, V, theta from filename like:
    P_40_Q_40_V_120_theta_120
    """
    pattern = r"P_(\-?\d+)_Q_(\-?\d+)_V_(\-?\d+)_theta_(\-?\d+)"
    
    match = re.search(pattern, filename)

    if not match:
        return None

    P = float(match.group(1))
    Q = float(match.group(2))
    V = float(match.group(3))
    theta = float(match.group(4))

    return P, Q, V, theta

def compute_tail_stats(data, head_percent):
    """
    Uses last 2/3 of data
    """
    n = len(data)
    start = int(head_percent * n)
    tail = data[start:]

    return np.max(tail), np.min(tail), np.average(tail)

def compute_tail_rms(data, head_percent):
    n = len(data)
    start = int(head_percent * n)
    tail = np.array(data[start:])
    
    
    return np.sqrt(np.mean(tail**2))

def compute_head(data):
    n = len(data)
    start = int(1/10 * n)
    end = int(1/2 * n)
    head = np.array(data[start:end])
    
    return np.average(head)

def compute_theta(Vphase, Iphase, head_percent):
    phase_diff = Iphase - Vphase
    phase_diff_wrapped = (phase_diff + np.pi) % (2*np.pi) - np.pi
    n = len(phase_diff_wrapped)
    start1 = int(1/10 * n)
    fault = int(1/2 * n)
    start2 = int(head_percent * n)
    head = np.array(phase_diff_wrapped[start1:fault])
    tail = np.array(phase_diff_wrapped[start2:])
    
    return np.mean(head), np.mean(tail)

# =========================
# MAIN PROCESSING
# =========================

results = []

filenames = os.listdir(DATA_FOLDER)
file_count = 0

base_files = set()
for f in filenames:
    if "_i" in f:
        base_files.add(f.replace("_i",""))
    else:
        base_files.add(f)

for filename in base_files:
    
    # get file path
    if is_V_drop:
        file_path = os.path.join(DATA_FOLDER, filename +"_i")
    else:
        file_path = os.path.join(DATA_FOLDER, filename)
    
    
    try:
        # load data
        if os.path.exists(file_path):
            # Time,I_inv_p,I_ph_p,Vgrid_p,Vgrid_ph_p,P_POC,Q_POC
            I_grid_1_data = pd.read_csv(file_path).iloc[:,1].values
            I_grid_2_data = pd.read_csv(file_path).iloc[:,2].values
            I_grid_3_data = pd.read_csv(file_path).iloc[:,3].values
            I_data = pd.read_csv(file_path).iloc[:,4].values
            I_phase_data = pd.read_csv(file_path).iloc[:,5].values
            V_grid_1_data = pd.read_csv(file_path).iloc[:,6].values
            V_grid_2_data = pd.read_csv(file_path).iloc[:,7].values
            V_grid_3_data = pd.read_csv(file_path).iloc[:,8].values
            V_data = pd.read_csv(file_path).iloc[:,9].values
            V_phase_data = pd.read_csv(file_path).iloc[:,10].values
            P_data = pd.read_csv(file_path).iloc[:,11].values
            Q_data = pd.read_csv(file_path).iloc[:,12].values
            V_inv_1_data = pd.read_csv(file_path).iloc[:,13].values
            V_inv_2_data = pd.read_csv(file_path).iloc[:,14].values
            V_inv_3_data = pd.read_csv(file_path).iloc[:,15].values
            I_inv_1_data = pd.read_csv(file_path).iloc[:,16].values
            I_inv_2_data = pd.read_csv(file_path).iloc[:,17].values
            I_inv_3_data = pd.read_csv(file_path).iloc[:,18].values
            
            # -----------------------------
            # Extract parameters
            # -----------------------------
            params = extract_params(filename)
            if params is None:
                print(f"⚠️ Skipped (bad filename): {filename}")
                continue
            
            P, Q, V_mag, V_theta = params
            
            # -----------------------------
            # Compute Metrics
            # -----------------------------
            # tail percent: 1/3 for direct vsource, 7/10 for V_drop for tail percent
            # max tail percent: 0
            tail_percent = 1/3
            max_tail_percent = 0
            
            if is_V_drop:
                tail_percent = 7/10
                max_tail_percent = 1/2
            
            I_max_tail, I_min_tail, I_avg_tail = compute_tail_stats(I_data, tail_percent)
            # I_max_all, I_min_all = compute_tail_stats(I_data, max_tail_percent)
            Iphase_max_tail, Iphase_min_tail, ___ = compute_tail_stats(I_phase_data, tail_percent)
            V1_avg_tail = compute_tail_rms(V_grid_1_data, tail_percent)
            V2_avg_tail = compute_tail_rms(V_grid_2_data, tail_percent)
            V3_avg_tail = compute_tail_rms(V_grid_3_data, tail_percent)
            I1_avg_tail = compute_tail_rms(I_grid_1_data, tail_percent)
            I2_avg_tail = compute_tail_rms(I_grid_2_data, tail_percent)
            I3_avg_tail = compute_tail_rms(I_grid_3_data, tail_percent)
            V_avg_tail = compute_head(V_data)
            Vphase_avg_tail,Iphase_avg_tail = compute_theta(V_phase_data,I_phase_data, tail_percent)
            __, __, P_avg_tail = compute_tail_stats(P_data, tail_percent)
            __, __, Q_avg_tail = compute_tail_stats(Q_data, tail_percent)
            V1_inv_tail = compute_tail_rms(V_inv_1_data, tail_percent)
            V2_inv_tail = compute_tail_rms(V_inv_2_data, tail_percent)
            V3_inv_tail = compute_tail_rms(V_inv_3_data, tail_percent)
            I1_inv_tail = compute_tail_rms(I_inv_1_data, tail_percent)
            I2_inv_tail = compute_tail_rms(I_inv_2_data, tail_percent)
            I3_inv_tail = compute_tail_rms(I_inv_3_data, tail_percent)

            # -----------------------------
            # Store Result
            # -----------------------------
            results.append([
                P, Q, V_mag, V_theta,
                I_max_tail, I_min_tail, I_avg_tail,
                Iphase_max_tail, Iphase_min_tail, Iphase_avg_tail,
                I1_avg_tail, I2_avg_tail, I3_avg_tail,
                V1_avg_tail, V2_avg_tail, V3_avg_tail,
                V_avg_tail, Vphase_avg_tail,
                P_avg_tail, Q_avg_tail,
                V1_inv_tail, V2_inv_tail, V3_inv_tail,
                I1_inv_tail, I2_inv_tail, I3_inv_tail
            ])
            
            print(f"✅ Processed: {file_path}")
            file_count = file_count + 1
        
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        
columns = [
    "P", "Q", "V_mag", "V_theta",
    "I_max_tail", "I_min_tail", "I_avg_tail",
    "Iphase_max_tail", "Iphase_min_tail", "Iphase_avg_tail",
    "I1_avg_tail", "I2_avg_tail", "I3_avg_tail",
    "V1_avg_tail", "V2_avg_tail", "V3_avg_tail",
    "V_avg_tail", "Vphase_avg_tail",
    "P_avg_tail", "Q_avg_tail",
    "V1_inv_tail", "V2_inv_tail", "V3_inv_tail",
    "I1_inv_tail", "I2_inv_tail", "I3_inv_tail"
]

summary_df = pd.DataFrame(results, columns=columns)
summary_path = OUTPUT_FILE
summary_df.to_csv(summary_path, index=False)

print("✅✅ SUMMARY FILE CREATED ✅✅")
print(summary_path)
print(file_count)