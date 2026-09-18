# Import the V5 Automation Library
import mhi.pscad

# Import other utilities to perform cool stuff
from mhi.pscad.utilities.file import File
import sys, os
import win32com.client
import shutil
import logging

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
working_dir = "../PSCX Files/"

#---------------------------------------------------------------------
# Main script 
#---------------------------------------------------------------------

# Source and destination folders for output data
src_folder = working_dir + project_name + fortran_ext
dst_folder = src_folder

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
        # Test 1 Changing Vref
        #-----------------------------------------------------

        print("Run 1 - changing Vref from 0.9 to 1.2")
        
        Vref.parameters(Value=0.9)
        
        project.run()
        # Save data to output folder
        folder = os.path.join(dst_folder, "Test_1")
        File.move_files(src_folder, folder, ".out", ".inf")
        
        print("Script is Done!")

    finally:
        #pscad.quit()
        pass
else:
    print("Failed to launch PSCAD")
    

# ------------------------------------------------------------------------------
#  End of script
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~