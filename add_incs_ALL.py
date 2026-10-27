import numpy as np
from netCDF4 import Dataset
import shutil
import sys


def cap_sum_at_one(arr):
    """
    Ensure sum(arr[:,j,k]) <= 1 by scaling categories proportionally.
    """
    out = arr.copy()
    sums = out.sum(axis=0)
    mask = sums > 1.0
    out[:, mask] /= sums[mask]
    return out


folder_root = "/work/n01/n01/elicoo/CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.2/cfgs/exp-build-notop/"

ens_tot = int(sys.argv[3])
restart_folder = sys.argv[1]
restart_string = sys.argv[2]

num_domains = 96
numcats = 6


# --------------------------------------------------------------------
# Variables with an ice category dimension
# --------------------------------------------------------------------

cat_fields = {
    "a_i": {"increment": "bckinseaice", "clip_zero": True, "cap_sum": True},
    "v_i": {"increment": "bckinicevol", "clip_zero": True, "cap_sum": False},
    "v_s": {"increment": "bckinsnvol", "clip_zero": True, "cap_sum": False},
    "t_su": {"increment": "bckinsist", "clip_zero": False, "cap_sum": False},
    "a_ip": {"increment": "bckinaip", "clip_zero": True, "cap_sum": True},
    "v_ip": {"increment": "bckinvip", "clip_zero": True, "cap_sum": False},
    "v_il": {"increment": "bckinvil", "clip_zero": False, "cap_sum": False},
    "e_s_l01": {"increment": "bckines1", "clip_zero": False, "cap_sum": False},
    "e_s_l02": {"increment": "bckines2", "clip_zero": False, "cap_sum": False},
    "e_s_l03": {"increment": "bckines3", "clip_zero": False, "cap_sum": False},
    "e_i_l01": {"increment": "bckinei1", "clip_zero": False, "cap_sum": False},
    "e_i_l02": {"increment": "bckinei2", "clip_zero": False, "cap_sum": False},
    "e_i_l03": {"increment": "bckinei3", "clip_zero": False, "cap_sum": False},
    "e_i_l04": {"increment": "bckinei4", "clip_zero": False, "cap_sum": False},
    "e_i_l05": {"increment": "bckinei5", "clip_zero": False, "cap_sum": False},

}

ocean_fields = {
    "sn": {"increment": "bckinsn", "clip_zero": False, "cap_sum": False},
    "tn": {"increment": "bckintn", "clip_zero": False, "cap_sum": False},
}

# --------------------------------------------------------------------
# Variables without an ice category or lev dimension
# --------------------------------------------------------------------

scalar_fields = {
    "u_ice": {"increment": "bckinuice", "clip_zero": False},
    "v_ice": {"increment": "bckinvice", "clip_zero": False},
}

# --------------------------------------------------------------------

if __name__ == "__main__":

    print("Starting")

    for ens_number in range(1, ens_tot + 1):

        print(f"Ensemble {ens_number}")

        for dom in range(num_domains):

            #print(f"  Domain {dom}")

            with Dataset(
                folder_root + f"ens{ens_number}/assim_background_increments_{dom:04d}.nc",
                "r",
            ) as increment_file, Dataset(
                folder_root + f"ens{ens_number}/assim_background_state_DI_{dom:04d}.nc",
                "r",
            ) as background_file:

                analyses = {}

                # ---------------------------------------------------------
                # Category variables
                # ---------------------------------------------------------

                for restart_var, info in cat_fields.items():

                    analyses[restart_var] = []

                    for ice_cat in range(1, numcats + 1):

                        inc_name = f"{info['increment']}_cat_{ice_cat}"
                        bkg_name = f"{restart_var}_cat_{ice_cat}"

                        analysis = (
                            increment_file[inc_name][0, :, :]
                            + background_file[bkg_name][0, :, :]
                        )

                        if info["clip_zero"]:
                            analysis[analysis < 0] = 0

                        analyses[restart_var].append(analysis)

                    analyses[restart_var] = np.array(analyses[restart_var])

                    if info["cap_sum"]:
                        analyses[restart_var] = cap_sum_at_one(
                            analyses[restart_var]
                        )

                # ---------------------------------------------------------
                # Scalar variables
                # ---------------------------------------------------------

                for restart_var, info in scalar_fields.items():

                    analysis = (
                        increment_file[info["increment"]][0, :, :]
                        + background_file[restart_var][0, :, :]
                    )

                    if info["clip_zero"]:
                        analysis[analysis < 0] = 0

                    analyses[restart_var] = analysis

                # ---------------------------------------------------------
                # OCean variables
                # ---------------------------------------------------------

                for restart_var, info in ocean_fields.items():

                    analysis = (
                            increment_file[info["increment"]][0, :, :, :]
                        + background_file[restart_var][0, :, :, :]
                    )

                    if info["clip_zero"]:
                        analysis[analysis < 0] = 0

                    analyses[restart_var] = analysis

                #if dom == 1:
                #    print (analyses)



            # -------------------------------------------------------------
            # Backup restarts
            # -------------------------------------------------------------

            #restart = (
            #    folder_root
            #    + f"ens{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc"
            #)

            #shutil.copy(restart, restart.replace(".nc", "_pre.nc"))

            #ocean_restart_string = restart_string.replace("ice_", "")
            #restart_ocean = ( folder_root
            #    + f"ens{ens_number}/{restart_folder}/{ocean_restart_string}_{dom:04d}.nc"
            #)

            #shutil.copy(restart_ocean, restart_ocean.replace(".nc", "_pre.nc"))

            folder = folder_root + f"ens{ens_number}/{restart_folder}/"

            restart     = folder + f"{restart_string}_{dom:04d}.nc"
            restart_pre = folder + f"{restart_string}_pre_{dom:04d}.nc"
            shutil.copy(restart, restart_pre)

            ocean_restart_string = restart_string.replace("ice_", "")
            restart_ocean     = folder + f"{ocean_restart_string}_{dom:04d}.nc"
            restart_ocean_pre = folder + f"{ocean_restart_string}_pre_{dom:04d}.nc"
            shutil.copy(restart_ocean, restart_ocean_pre)

            # -------------------------------------------------------------
            # Write analyses back
            # -------------------------------------------------------------

            with Dataset(restart, "r+") as nc:

                # Variables with category dimension
                for restart_var in cat_fields:
                    nc.variables[restart_var][0, :, :, :] = analyses[restart_var]

                # Variables without category dimension
                for restart_var in scalar_fields:
                    nc.variables[restart_var][0, :, :] = analyses[restart_var]


            with Dataset(restart_ocean, "r+") as nc:
                for ocean_var in ocean_fields:
                    nc.variables[ocean_var][0,:,:,:] = analyses[ocean_var]
