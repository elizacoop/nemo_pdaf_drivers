import numpy as np
from netCDF4 import Dataset
import pandas as pd
import sys

obs_file = Dataset('/work/n01/n01/elicoo/observations/data_v3_2010-2023.nc','r')
time_step = int(sys.argv[1])####77

dates = pd.to_datetime(obs_file['time'][:].astype(int).astype(str),format='%Y%m%d')

#timesteps_for_next_run = 24.*((dates[time_step+1] - dates[time_step]).days)

print (int(obs_file['time'][time_step]))

