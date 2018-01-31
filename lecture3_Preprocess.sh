#!/bin/bash

# Preprocesses fMRI data automatically all the way to normalization

# Dirk Bernhardt-Walther (bernhardt-walther@psych.utoronto.ca)
# January 2018
# Winter-2018-PSY5212H-S-LEC0101: TOPICS IN PERCEPTION III
# Functional Magnetic Resonance Imaging of the Human Visual System

# Run while you're in the data directory
# Usage: scripts/Preprocess <Subj> <prefix> <MotionCorrectPrefix> <MotionCorrectVOlume>
# data file is assumed to be at: 
#   ${Subj}/ref_data/${Subj}_${Prefix}.nii.gz
# mprage is assumed to be at:
#   ${Subj}/analysis/${Subj}_t1_mprage_deobl+orig


# setting variables
subj=$1
prefix=$2
epi=${subj}_${prefix}.nii.gz
anat=${subj}_t1_mprage_deobl+orig
mcEPI=${subj}_$3_deobl+orig
mcVol=$4

smoothingLevels="2 4 6 8"

# sanity check: do files exist?
if ! [ -r ${subj}/ref_data/${epi} ]; then
   echo "ERROR: Could not read EPI from ${subj}/ref_data/${epi}."
   exit
fi

# check if mprage is already deobliqued
if [ -r ${subj}/analysis/${anat}.HEAD ]; then
   echo "MPRAGE is already deobliqued. :-)"
else
   # look for mprage
   pushd .
   cd ${subj}/analysis
   findAnat=`ls ${subj}_t1_mprage*.nii.gz`
   if ! [ -r ${findAnat} ]; then
      echo "ERROR: Could not read EPI from ${subj}/ref_data/${epi}."
      popd
      exit
   fi

   # deoblique MPRAGE
   3dWarp -deoblique \
          -prefix ${subj}_t1_mprage_deobl \
          ${findAnat}

  popd

fi

# remember the current directory
pushd .


# Deoblique
cd ${subj}/ref_data
3dWarp -deoblique \
       -prefix \
       ${subj}_${prefix}_deobl ${epi}


# Motion correct
if ![ -r ${mcEPI}.HEAD ]; then
   popd
   echo "ERROR: Could not read motion correction EPI from ${subj}/ref_data/${mcEPI}."
   exit
fi

3dvolreg -zpad 4 \
         -prefix ${subj}_${prefix}_vr \
         -dfile ${subj}_${prefix}_vr.1D \
         -base ${mcEPI}\[${mcVol}\] \
         -verbose \
         ${subj}_${prefix}_deobl+orig


# housekeeping
cd ..
if ! [ -d reg_data ]; then
   mkdir reg_data
   cp analysis/${anat}.* reg_data
fi
if ! [ -d params ]; then
   mkdir params
fi
mv ref_data/${subj}_${prefix}_vr+orig.* reg_data/
mv ref_data/${subj}_${prefix}_vr.1D params
cd reg_data


# align EPI to anatomical
align_epi_anat.py \
   -anat ${anat} \
   -epi ${subj}_${prefix}_vr+orig \
   -epi_base mean \
   -epi2anat \
   -volreg off \
   -tshift off \
   -deoblique off \
   -save_vr

# smooth and normalize
for sm in ${smoothingLevels}; do
   # smoothing
   3dmerge \
      -1blur_fwhm ${sm} \
      -doall \
      -prefix ${subj}_${prefix}_sm${sm} \
      ${subj}_${prefix}_vr_al+orig

   # normalization
   3dTstat \
      -prefix ${subj}_${prefix}_sm${sm}_mean \
      ${subj}_${prefix}_sm${sm}+orig

   3dcalc \
      -a ${subj}_${prefix}_sm${sm}_mean+orig \
      -b ${subj}_${prefix}_sm${sm}+orig \
      -expr 'min(200,a/b*100)-100' \
      -float \
      -prefix ${subj}_${prefix}_sm${sm}_norm

done

# also normalize the unsmoothed volume
3dTstat \
   -prefix ${subj}_${prefix}_sm0_mean \
   ${subj}_${prefix}_vr_al+orig

3dcalc \
   -a ${subj}_${prefix}_sm0_mean+orig \
   -b ${subj}_${prefix}_vr_al+orig \
   -expr 'min(200,a/b*100)-100' \
   -float \
   -prefix ${subj}_${prefix}_sm0_norm


# check if brain mask already exists and create if it doesn't
if ! [ -r ${subj}_wholeBrain_mask+orig.HEAD ]; then

   echo "Creating brain mask ..."

   3dSkullStrip \
      -input ${anat} \
      -prefix ${subj}_t1_skullStripped

   3dresample \
      -master ${subj}_${prefix}_sm0_mean+orig \
      -prefix ${subj}_${prefix}_maskAnat \
      -inset ${subj}_t1_skullStripped+orig

   3dcalc \
      -a ${subj}_${prefix}_maskAnat+orig \
      -expr 'step(a)' \
      -prefix ${subj}_wholeBrain_mask

   3dcalc \
      -a ${subj}_wholeBrain_mask+orig \
      -expr '1-a' \
      -prefix ${subj}_nonBrain_mask

   cp ${subj}_t1_skullStripped+orig.* ../analysis
   cp ${subj}_wholeBrain_mask+orig.* ../analysis

   rm ${subj}_${prefix}_maskAnat+orig.*
fi


# now run quality assurance

echo "Computing SNR for Quality Assurance"

# first, temporal SNR
# compute stdev over time
3dTstat \
   -stdev \
   -prefix ${subj}_${prefix}_sm0_stdev \
   ../reg_data/${subj}_${prefix}_vr_al+orig

# compute mean/stdev
3dcalc \
   -a ${subj}_${prefix}_sm0_mean+orig \
   -b ${subj}_${prefix}_sm0_stdev+orig \
   -expr 'a/b' \
   -prefix ${subj}_${prefix}_Temporal_SNR


# now spatial SNR

# compute mean inside and outside the brain as a funciton of time
3dmaskave \
   -mask ${subj}_wholeBrain_mask+orig \
   ${subj}_${prefix}_vr_al+orig \
   > ${subj}_${prefix}_meanInside.1D

3dmaskave \
   -mask ${subj}_nonBrain_mask+orig \
   ${subj}_${prefix}_vr_al+orig \
   > ${subj}_${prefix}_meanOutside.1D

# Divide the two time series:
1deval \
   -ok_1D_text \
   -a ${subj}_${prefix}_meanInside.1D \
   -b ${subj}_${prefix}_meanOutside.1D \
   -expr 'a/b' \
   > ${subj}_${prefix}_SpatialSNR.1D

# Compute and display mean over time:
3dTstat \
   -prefix stdout: \
   ${subj}_${prefix}_SpatialSNR.1D\' \
   > ${subj}_${prefix}_meanSpatialSNR.1D

echo "Mean spatial SNR: `cat ${subj}_${prefix}_meanSpatialSNR.1D`"

mv *SNR* ../analysis

# reinstate previous directory
popd

# Some sage advice at the end
echo "==============================================="
echo "Preprocessing complete."
echo "Please make sure to inspect the results!"
echo "Do not trust the output of this script blindly!"
echo "==============================================="



	
