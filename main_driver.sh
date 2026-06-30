#!/bin/bash


#things which many scripts need can be exported? Buy maybe simpler to use command line args 
#will trial this first


#Will assume that we start with a spin-up set of rester files, i.e. first thing to do is an assimilation on some files
#that WON'T MATCH the ongoing file and folder name patterns

FIRST_STEP=77 #obs time index referring to first (post-spin) assimilation
TOTAL_STEPS=26
last_step=$((FIRST_STEP + TOTAL_STEPS))
OBSFILE='/work/n01/n01/elicoo/observations/data_v3_2010-2023.nc' #needed in several places
MEMBERS=9

#Set spinup dir and filestring here
SPINDIR="somehitng"
SPINSTRING="ORCA2_someting"

#SET UP STRING TEMPLATES FOR THE INDIR, INSTRING,INICESTRNG, OUTDIR, OUTSTRING, OUTICESTRING



#Do the assimilation
#construct the outdir and outstrings?? usinf common PREFIX??
#**sbatch run_assimilation --SPINDIR --SPINSTRING --SPINICESTRING  --OBSFILE
#??these are in /restart_step0 but with non-standard string - ideally set to be step0 in the inital nemo ens run
# at this point we are at STEP 77, having already done the assimilation

#OUTER TIME LOOP
#for time_counter in range(FIRST_SETP:FIRST_STEP+TOTAL_Steps):
for ((i=FIRST_STEP; i<=last_step; i++)); do
	#define the step counter here 
	COUNTER=$((i-FIRST_STEP))
	CPONE=$((COUNTER +1))
       	echo "i=$i COUNTER=$COUNTER CPONE=$CPONE"
        #CALCUlate next RUN TIME HERE???
	source  /work/n01/n01/elicoo/myvenv/bin/activate 
        NXTRNTS=$(python get_runtime.py "$i")
	echo "$i"
	echo "$NXTRNTS"
	START_STRING=$(python get_next_start_string.py "$i")
	echo "$START_STRING"
	deactivate


	#DEFINE INDIR,INSTRING,INICESTRNG, OUTDIR, OUTSTRING, OUTICESTRING DEPENDING IN TIME_COUNTER AND next run time AND START_string
	INDIR="./restart_step${COUNTER}"
	if [ "$COUNTER" -eq 0 ]; then
             INSTRING="ORCA2_00034848_ens_spin_toend2013"
	     INICESTRING="ORCA2_00034848_ens_spin_ice_toend2013"
        else
		INSTRING=$(printf "ORCA2_%08d_noassimens_step%d" "$LAST_NXTRNTS" "$COUNTER") #FILE=$(printf "restart_%08d.dat" "$NUM") ORCA2_00000360_ens_step1_0094.nc
		INICESTRING=$(printf "ORCA2_%08d_noassimens_ice_step%d" "$LAST_NXTRNTS" "$COUNTER")
        fi

	OUTDIR="./restart_step$CPONE"
	OUTSTRING="noassimens_step$CPONE"
	OUTICESTRING="noassimens_ice_step$CPONE"
        #echo "INDIR=$INDIR"
	echo "INDIR=$INDIR   OUTDIR=$OUTDIR"
	echo "INSTRING=$INSTRING"
	echo "OUTSTRING=$OUTSTRING"



	#RUN NEMO ENSEMBLE (NEEDS instring, inicestring, indir, outstring, outicestring, outdir, startstring), NXTRNTS
	./run_ens_general_step_sublimit.sh "$INDIR" "$INSTRING" "$INICESTRING" "$OUTDIR" "$OUTSTRING" "$OUTICESTRING" "$NXTRNTS" "$START_STRING" "$MEMBERS"
	#^^ SHOULD SOMEWHERE PUT IN A STOP IF THE ABOVE FAILS, otherwise will cycle through all the timesteps
         
	#DO ASSIMILATION (NEEDS INDIR, INSTRING, INICESTRING, OBSFILE)
	echo "Starting assimilation"
	
	ASSIM_TIME=$((i+1))
	PREFIX=$(printf "ORCA2_%08d_" "$NXTRNTS")
	##echo "ASSIM_TIME=$ASSIM_TIME  PREFIX=$PREFIX"
	##echo "Using $OUTDIR, $OUTSTRING, $OUTICESTRING, $OBSFILE"
	##./run_general_assimilation.sh "$OUTDIR" "$PREFIX" "$OUTSTRING" "$OUTICESTRING" "$ASSIM_TIME" "$OBSFILE" "$MEMBERS"

	#ADD INCREMENTS needs folder, string and num_ens
        OUTLONGSTRING=${PREFIX}${OUTICESTRING}
	echo "Addin increments using $OUTDIR $OUTLONGSTRING $MEMBERS" #Addin increments using ./restart_step1 ORCA2_00000360_ 4

	##source  /work/n01/n01/elicoo/myvenv/bin/activate
	##python add_increments.py "$OUTDIR" "$OUTLONGSTRING" "$MEMBERS"
	##deactivate
        
	echo "Increments NOT added"

	#KEEP THIS value of NXTRNTS and START_STRING for the following instring
	LAST_NXTRNTS="$NXTRNTS"
	LAST_START_STRING="$START_STRING" #??are the types OK here?? **don't need this one actually
	
done










