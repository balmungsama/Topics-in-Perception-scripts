#!/bin/bash

subject=$1
prefix="../reg_data/${subject}_fpo"
mcParams="../params/${subject}_fpo_vr.1D"
smLevels="0 2 4 6 8"

# save current directory
pushd .

cd ${subject}/regressions

# loop over all smoothing levels
for sm in ${smLevels}; do

  suffix="_sm${sm}_norm+orig"

  # this is the actual regression command
  3dDeconvolve -input \
       ${prefix}1${suffix} \
       ${prefix}2${suffix} \
      -mask ../analysis/${subject}_wholeBrain_mask+orig \
      -polort 3 \
      -num_stimts 10 \
      -stim_times 1 faces.1D 'BLOCK(18,1)' -stim_label 1 faces \
      -stim_times 2 scenes.1D 'BLOCK(18,1)' -stim_label 2 scenes \
      -stim_times 3 objects.1D 'BLOCK(18,1)' -stim_label 3 objects \
      -stim_times 4 scrambled_objects.1D 'BLOCK(18,1)' -stim_label 4 scrambled_objects \
      -stim_file 5 ${mcParams}\[1\] -stim_label 5 mc_params1 -stim_base 5 \
      -stim_file 6 ${mcParams}\[2\] -stim_label 6 mc_params2 -stim_base 6 \
      -stim_file 7 ${mcParams}\[3\] -stim_label 7 mc_params3 -stim_base 7 \
      -stim_file 8 ${mcParams}\[4\] -stim_label 8 mc_params4 -stim_base 8 \
      -stim_file 9 ${mcParams}\[5\] -stim_label 9 mc_params5 -stim_base 9 \
      -stim_file 10 ${mcParams}\[6\] -stim_label 10 mc_params6 -stim_base 10 \
      -num_glt 3 \
      -glt 1 ScenesVsObjectsAndFaces.1D -glt_label 1 ScenesVsObjectsAndFaces \
      -glt 1 FacesVsScenesAndObjects.1D -glt_label 2 FacesVsScenesAndObjects \
      -glt 1 ObjectsVsScrambledObjects.1D -glt_label 3 ObjectsVsScrambledObjects \
      -bucket ./${subject}_fpo_sm${sm}_bucket \
      -errts ./${subject}_fpo_sm${sm}_residuals \
      -jobs 4 \
      -fout
done

popd

