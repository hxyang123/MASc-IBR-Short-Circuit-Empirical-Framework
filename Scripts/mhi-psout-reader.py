import mhi.psout
import pandas as pd

psout_file = '../PSCAD Results/PSOUT Files/No-sys-IV-q120v-60p-23-11-25.psout'
csv_file_name = 'No-sys-IV-q120v-60p-23-11-25'
num_runs = 18

fields_to_record = ['Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/1', 
                    'Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/2', 
                    'Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/3',
                    'Root/Main/PVFarm_GFL_GFM_2/I_inv_p/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/I_inv_n/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/I_inv_z/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_p/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_n/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_z/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_ph_p/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_ph_n/Record/1',
                    'Root/Main/PVFarm_GFL_GFM_2/Vgrid_ph_z/Record/1']

fields_to_record2 = ['Root/Main/Igrid_POC/Record/1', 
                    'Root/Main/Igrid_POC/Record/2', 
                    'Root/Main/Igrid_POC/Record/3',
                    'Root/Main/I_inv_p/Record/1',
                    'Root/Main/I_inv_n/Record/1',
                    'Root/Main/I_inv_z/Record/1',
                    'Root/Main/Vgrid_p/Record/1',
                    'Root/Main/Vgrid_n/Record/1',
                    'Root/Main/Vgrid_z/Record/1',
                    'Root/Main/Vgrid_ph_p/Record/1',
                    'Root/Main/Vgrid_ph_n/Record/1',
                    'Root/Main/Vgrid_ph_z/Record/1']

csv_folder = '../PSCAD Results/'


with mhi.psout.File(psout_file) as file:
    # Extract
    df = pd.DataFrame()
    
    for i in range(0,num_runs):
        # simulation run number
        run = file.run(i)
        
        # Get time vector from known signal
        if i == 0:
            time_trace = run.trace(file.call(fields_to_record[0]))
            df['Time'] = time_trace.domain.data # domain = time vector
        
        # Loop over desired signals
        for path in fields_to_record:
            call_obj = file.call(path) # identify signal by its channel name/path
            trace = run.trace(call_obj) # get time trace for that signal
            signal_name = trace['Description'] 
            df[signal_name + '-' + str(i)] = trace.data # add signal data as a column
            
        # Write to CSV
    df.to_csv(csv_folder + csv_file_name, index=False)