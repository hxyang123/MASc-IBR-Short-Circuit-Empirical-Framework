# Import the V5 Automation Library
import mhi.pscad
import mhi.psout

# Import other utilities to perform cool stuff
from mhi.pscad.utilities.file import File
import sys, os
import win32com.client
import shutil
import logging
import pandas as pd
import time

#---------------------------------------------------------------------
# Configuration
#---------------------------------------------------------------------
print("Automation Library:", mhi.pscad.VERSION)
logging.basicConfig(level=logging.INFO,format="%(levelname)-8s %(name)-26s %(message)s")
# Ignore INFO msgs from automation (eg, mhi.pscad, mhi.common, ...)
logging.getLogger('mhi').setLevel(logging.WARNING)
LOG = logging.getLogger('main')

# Get Fortran compiler versions
fortran_ext = '.gf81_x86'
project_name = 'Generic_GFM_switching_no_sys'

# Working directory
working_dir = "../../PSCX Files/"

#---------------------------------------------------------------------
# Main script 
#---------------------------------------------------------------------

# Source and destination folders for output data
src_folder = working_dir + project_name + fortran_ext
dst_folder = "../PSCAD_auto_results/"
output_file_name = src_folder + "/OutputFile1.psout"

# Launch PSCAD and Fortran version
pscad = mhi.pscad.launch(version='5.0.1')

if pscad:
    try:
        # Load the project
        pscad.load([working_dir + project_name + ".pscx"])
        project = pscad.project(project_name) 
        project.focus()

        # Get the "Main" canvas
        main = project.canvas('Main')
        
        # Get to the Solar Farm canvas and system canvas
        PVFarm = main.component(266442602)
        PVFarm_canvas = PVFarm.canvas()
        
        # Get Inverter References
        Pref = PVFarm_canvas.component(1727572265)
        Qref = PVFarm_canvas.component(882898928)
        Vsource = main.component(1684857703)
        
        #-----------------------------------------------------
        # Testing various P,Q,V,theta values
        #-----------------------------------------------------

        # Example: Vref.parameters(Value=0.9)
        print("Run - changing P, Q, V, theta and recording I, I_theta")
        
        MVA = 100
        scale = 0.81649658092772603273242802490196
        P_values = [0, 20, 50, 90, 100]
        Q_values = [0, 20, 50, 90, 100]
        #P_values = [0, 20, 50, 100]
        #Q_values = [0, 20, 50, 100]
        V_values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120]
        theta_values = [-60, -30, 0, 30, 60, 120]
        
        #print(Pref.parameters())
        #print(Qref.parameters())
        #print(Vsource.parameters())
        
        fields_to_record = ['Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/2',
                            'Root/Main/PVFarm_GFL_GFM_2/Igrid_POC/Record/3',
                            'Root/Main/PVFarm_GFL_GFM_2/I_inv_p/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/I_ph_p/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/Vgrid_POC/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/Vgrid_POC/Record/2',
                            'Root/Main/PVFarm_GFL_GFM_2/Vgrid_POC/Record/3',
                            'Root/Main/PVFarm_GFL_GFM_2/Vgrid_p/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/Vgrid_ph_p/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/SimpleSF_15_2/P/Record/1',
                            'Root/Main/PVFarm_GFL_GFM_2/SimpleSF_15_2/Q/Record/1']

        # Run for every variables
        for pval in P_values:
            for qval_temp in Q_values:
                # qval = (MVA**2 - pval**2)**0.5
                qval = qval_temp
                if pval == 100 and qval != 0:
                    continue
                if qval == 100 and pval != 0:
                    continue
                if qval == 90 and pval >= 50:
                    continue
                if pval == 90 and qval >= 50:
                    continue
                if pval == 0 and qval == 0:
                    continue
                
                for vval in V_values:
                    for thetaval in theta_values:
                        print("Run - P={}, Q={}, V={}, theta={} and recording I, I_theta".format(
                            pval, qval, vval, thetaval))
                        if os.path.exists(dst_folder + "P_" + str(pval) + "_Q_" + str(qval_temp) + 
                                      "_V_" + str(vval) +"_theta_" + str(thetaval)):
                            print("File exists - skipped")
                            continue
                        
                        Pref.parameters(Value=pval)
                        Qref.parameters(Value=qval)
                        Vsource.parameters(Vm=vval)
                        Vsource.parameters(Ph=thetaval)
                        project.run()
                        time.sleep(1)
                        
                        # Record data
                        with mhi.psout.File(output_file_name) as file:
                            # Extract
                            df = pd.DataFrame()
                            
                            # simulation run number
                            run = file.run(0)
                                
                            # Get time vector from known signal
                            time_trace = run.trace(file.call(fields_to_record[0]))
                            df['Time'] = time_trace.domain.data # domain = time vector
                                
                            # Loop over desired signals
                            for path in fields_to_record:
                                call_obj = file.call(path) # identify signal by its channel name/path
                                trace = run.trace(call_obj) # get time trace for that signal
                                signal_name = trace['Description'] 
                                df[signal_name] = trace.data # add signal data as a column
                                    
                            # Write to CSV
                            df.to_csv(dst_folder + "P_" + str(pval) + "_Q_" + str(qval_temp) + 
                                      "_V_" + str(vval) +"_theta_" + str(thetaval), index=False)

        print("Script is Done!")

    finally:
        pscad.quit()
        pass
else:
    print("Failed to launch PSCAD")
    

# ------------------------------------------------------------------------------
#  End of script
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~