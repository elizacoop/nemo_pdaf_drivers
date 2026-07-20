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


folder_root = '/work/n01/n01/elicoo/CRISP_NEMO_PDAF/CRISP_NEMO_PDAF_1/nemo_5.0.1/cfgs/exp-build-notop/'

ens_tot = int(sys.argv[3])
restart_folder = sys.argv[1]
restart_string = sys.argv[2]

num_domains = 96
numcats = 6

# --------------------------------------------------------------------
# Information for each assimilated field
# --------------------------------------------------------------------

field_info = {
    "sic": {
        "increment": "bckinseaice",
        "background": "a_i",
        "restart": "a_i",
        "clip_zero": True,
        "cap_sum": True,
    },
    "siv": {
        "increment": "bckinicevol",
        "background": "v_i",
        "restart": "v_i",
        "clip_zero": True,
        "cap_sum": False,
    },
    "snv": {
        "increment": "bckinsnvol",
        "background": "v_s",
        "restart": "v_s",
        "clip_zero": True,
        "cap_sum": False,
    },
    "sist": {
        "increment": "bckinsist",
        "background": "t_su",
        "restart": "t_su",
        "clip_zero": False,
        "cap_sum": False,
    },
     "aip": {
        "increment": "bckinaip",
        "background": "a_ip",
        "restart": "a_ip",
        "clip_zero": True,
        "cap_sum": True,
    },
    "vip": {
        "increment": "bckinvip",
        "background": "v_ip",
        "restart": "v_ip",
        "clip_zero": True,
        "cap_sum": False,
    },
    "vil": {
        "increment": "bckinvil",
        "background": "v_il",
        "restart": "v_il",
        "clip_zero": False,
        "cap_sum": False,
    },
    "es1": {
        "increment": "bckines1",
        "background": "e_s_l01",
        "restart": "e_s_l01",
        "clip_zero": False,
        "cap_sum": False,
    },
    "es2": {
        "increment": "bckines2",
        "background": "e_s_l02",
        "restart": "e_s_l02",
        "clip_zero": False,
        "cap_sum": False,
    },
    "es3": {
        "increment": "bckines3",
        "background": "e_s_l03",
        "restart": "e_s_l03",
        "clip_zero": False,
        "cap_sum": False,
    },
    "ei1": {
        "increment": "bckinei1",
        "background": "e_i_l01",
        "restart": "e_i_l01",
        "clip_zero": False,
        "cap_sum": False,
    },
    "ei2": {
        "increment": "bckinei2",
        "background": "e_i_l02",
        "restart": "e_i_l02",
        "clip_zero": False,
        "cap_sum": False,
    },
    "ei3": {
        "increment": "bckinei3",
        "background": "e_i_l03",
        "restart": "e_i_l03",
        "clip_zero": False,
        "cap_sum": False,
    },
    "ei4": {
        "increment": "bckinei4",
        "background": "e_i_l04",
        "restart": "e_i_l04",
        "clip_zero": False,
        "cap_sum": False,
    },
    "ei5": {
        "increment": "bckinei5",
        "background": "e_i_l05",
        "restart": "e_i_l05",
        "clip_zero": False,
        "cap_sum": False,
    },

}

scalar_fields = {
    "uice": {
        "increment": "bckinuice",
        "background":"u_ice",
        "restart":"u_ice",
        "clip_zero": False,

    },
        "vice": {
        "increment": "bckinvice",
        "background":"v_ice",
        "restart":"v_ice",
        "clip_zero": False,

    },

}






# --------------------------------------------------------------------

if __name__ == "__main__":

    print("Starting")

    for ens_number in range(1, ens_tot + 1):

        print(f"Ensemble {ens_number}")

        for dom in range(num_domains):

            print(f"  Domain {dom}")

            with Dataset(
                folder_root + f"ens_{ens_number}/assim_background_increments_{dom:04d}.nc",
                "r",
            ) as increment_file, Dataset(
                folder_root + f"ens_{ens_number}/assim_background_state_DI_{dom:04d}.nc",
                "r",
            ) as background_file:

                # Dictionary to hold the analyses
                analyses = {name: [] for name in field_info}

                # ---------------------------------------------------------
                # Calculate analysis for every variable and category
                # ---------------------------------------------------------

                for ice_cat in range(1, numcats + 1):

                    for name, info in field_info.items():

                        inc_name = f"{info['increment']}_cat_{ice_cat}"
                        bkg_name = f"{info['background']}_cat_{ice_cat}"

                        analysis = (
                            increment_file[inc_name][0, :, :]
                            + background_file[bkg_name][0, :, :]
                        )

                        if info["clip_zero"]:
                            analysis[analysis < 0] = 0

                        analyses[name].append(analysis)

                # Convert lists to numpy arrays
                for name in analyses:
                    analyses[name] = np.array(analyses[name])

                # Apply any physical constraints
                for name, info in field_info.items():
                    if info["cap_sum"]:
                        analyses[name] = cap_sum_at_one(analyses[name])






                #scalar equivalents
                for restart_var, info in scalar_fields.items():

                    analysis = (
        increment_file[info["increment"]][0] +
        background_file[restart_var][0]
                     ) 

                    if info["clip_zero"]:
                        analysis[analysis < 0] = 0

                    analyses[restart_var] = analysis




            # -------------------------------------------------------------
            # Backup restart
            # -------------------------------------------------------------

            restart = (
                folder_root
                + f"ens_{ens_number}/{restart_folder}/{restart_string}_{dom:04d}.nc"
            )

            shutil.copy(restart, restart.replace(".nc", "_pre.nc"))

            # -------------------------------------------------------------
            # Write analyses back to restart
            # -------------------------------------------------------------

            with Dataset(restart, "r+") as nc:

                for info in field_info.values():
                    nc.variables[info["restart"]][0, :, :, :] = analyses[info["restart"]]
                for restart_var in scalar_fields:
                    nc.variables[restart_var][0, :, :] = analyses[restart_var]
