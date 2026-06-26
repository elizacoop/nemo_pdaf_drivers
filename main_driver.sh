#!/bin/bash


#things which many scripts need can be exported? Buy maybe simpler to use command line args 
#will trial this first


#Will assume that we start with a spin-up set of rester files, i.e. first thing to do is an assimilation on some files
#that WON'T MATCH the ongoing file and folder name patterns

FIRST_STEP=77 #obs time index referring to first (post-spin) assimilation
TOTAL_STEPS=3
last_step=$((FIRST_STEP + TOTAL_STEPS))
OBSFILE='/work/n01/n01/elicoo/observations/data_v3_2010-2023.nc' #needed in several places

#Set spinup dir and filestring here
SPINDIR="somehitng"
SPINSTRING="ORCA2_someting"

#SET UP STRING TEMPLATES FOR THE INDIR, INSTRING,INICESTRNG, OUTDIR, OUTSTRING, OUTICESTRING



#Do the assimilation
#construct the outdir and outstrings?? usinf common PREFIX??
#**sbatch run_assimilation --SPINDIR --SPINSTRING --SPINICESTRING  --OBSFILE


#OUTER TIME LOOP
#for time_counter in range(FIRST_SETP:FIRST_STEP+TOTAL_Steps):
for ((i=FIRST_STEP; i<=last_step; i++)); do
       	#CALCUlate next RUN TIME HERE???
	source  /work/n01/n01/elicoo/myvenv/bin/activate 
        NXTRNTS=$(python get_runtime.py "$i")
	echo "$i"
	echo "$NXTRNTS"
	deactivate

	#DEFINE INDIR,INSTRING,INICESTRNG, OUTDIR, OUTSTRING, OUTICESTRING DEPENDING IN TIME_COUNTER AND next run time

	#RUN NEMO ENSEMBLE (NEEDS instring, inicestring, indir, outstring, outicestring, outdir)

	#DO ASSIMILATION (NEEDS INDIR, INSTRING, INICESTRING)

	#ADD INCREMENTS

	
done










