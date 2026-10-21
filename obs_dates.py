import sys, os, calendar
from datetime import date
from netCDF4 import Dataset, num2date

OBSFILE = '/work/n01/n01/elicoo/observations/orca1_hicexaice_v2.1.nc'
STEPS_PER_DAY = 48 #int(os.environ.get('STEPS_PER_DAY', 48))


with Dataset(OBSFILE) as nc:
    t = nc['time']
    cal = getattr(t, 'calendar', 'standard')
    raw = num2date(t[:], units=t.units, calendar=cal)
dates = [date(d.year, d.month, d.day) for d in raw]   # drops time of day

def model_days(d0, d1):
    days = (d1 - d0).days
    #if not MODEL_HAS_LEAP:
    #    days -= sum(1 for y in range(d0.year, d1.year + 1)
    #                if calendar.isleap(y) and d0 < date(y, 2, 29) <= d1)
    return days

what, n = sys.argv[1], int(sys.argv[2])
if what == 'steps':      # model steps from obs n to obs n+1
    print(model_days(dates[n], dates[n+1]) * STEPS_PER_DAY)
elif what == 'start':    # start date string of obs n
    print(dates[n].strftime('%Y%m%d'))
