import numpy as np
from netCDF4 import Dataset
import shutil

def cap_sum_at_one(arr):
    """
    For each (j,k), ensure sum(arr[:,j,k]) <= 1.
    If the sum exceeds 1, scale all 6 values proportionally
    so the new sum equals 1.

    Parameters
    ----------
    arr : ndarray, shape (6, ny, nx)

    Returns
    -------
    ndarray
        Adjusted array.
    """
    out = arr.copy()

    sums = out.sum(axis=0)          # shape (ny, nx)
    mask = sums > 1.0

    out[:, mask] /= sums[mask]

    return out

#checking that en set up up ok - yes
#with Dataset("/work/n01/n01/elicoo/CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/ens_9/assim_background_increments_0013.nc", "r") as nc:
#    temp = nc.variables["bckinseaice_cat_6"][:]
#    print(temp.shape)
folder_root = '/work/n01/n01/elicoo/CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/'

ens_tot = 19 #set this somewhere higher up??
num_domains = 2#96 #and this
numcats = 6 #and this
restart_folder = 'restart_step0' #and do something with this
restart_string = 'ORCA2_00034848_ens_spin_ice_toend2013'
#restart has a_i(time_counter, numcat, y, x) for SIC
#inc file has bckinseaice_cat_1(time_counter, y, x) etc for SIC
#background file has a_i_cat_1(time_counter, y, x) etc for SIC

if __name__ == "__main__":
    print ('starting to run')
    for ens_number in range (1,ens_tot+1):
            print (ens_number)
            for dom in range(num_domains):
                print (dom)
                with Dataset(folder_root + f'ens_{ens_number}/assim_background_increments_{dom:04d}.nc','r') as increment_file, \
                    Dataset(folder_root + f'ens_{ens_number}/assim_background_state_DI_{dom:04d}.nc','r') as background_file:

                    #restart_file = Dataset(folder_root + f'ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc','r')

                    total_analysis = []
                    for ice_cat in range (1,numcats+1):
                        print (ice_cat)
                        inc_string_sic = f"bckinseaice_cat_{ice_cat}"
                        bck_string_sic = f"a_i_cat_{ice_cat}" 
                    

                        #seems cleaner to calculate the new values, do testing, and then put them into the restart
                        analysis = increment_file[inc_string_sic][0,:,:] + background_file[bck_string_sic][0,:,:]
                        analysis[analysis <0.] = 0. #setting negative SIC values to zero
                        total_analysis.append(analysis)



                    total_analysis = np.array(total_analysis)
                    #physical checks for the total SIC
                    #print(total_analysis)
                    print (np.shape(total_analysis))
                    physical_analysis = cap_sum_at_one(total_analysis)
                    '''if np.allclose(physical_analysis,total_analysis):
                        continue
                    else:
                        print(total_analysis.sum(axis=0))
                        print(physical_analysis.sum(axis=0))'''

                    #NOW replace the fields in the restarts
                    shutil.copy(folder_root + f'ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc',folder_root + f'ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}_pre.nc')

                    with Dataset(folder_root + f'ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc', "r+") as nc:
                        nc.variables["a_i"][0,:,:,:] = physical_analysis
                        #restart_file = Dataset(folder_root + f'ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc','r')
                

                

                


