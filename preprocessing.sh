# for loop looping through each subject
subjDirs=(0004) #(0003 0004)
anatom=0005
functDirs=(0008 0009)
smooths=(2 4 6 8)

topDir="/home/eusebio2/data"

# SCRIPT BEGINS HERE

for subj in ${subjDirs[@]}; do 

	cd $topDir/$subj
	mkdir analysis
	cd analysis
	dcm2niix -o . -z y -f $subj"_%p_%s" ../dicom/$anatom
	ls

	# get t1.nii filename
	t1_scan=$(ls $subj*.nii.gz)
	t1_scan=$(basename $t1_scan .nii.gz)
	# deoblique anatomical t1 scan
	3dWarp -deoblique -prefix $t1_scan'_deobl' $t1_scan'.nii.gz'

	# make directories
	cd ..
	mkdir analysis
	mkdir ref_data
	mkdir reg_data
	mkdir params
	mkdir regressions
	mkdir matlab
	mkdir masks

	### FUNCTIONAL ###
	for funct in ${functDirs[@]}; do

		cd $topDir/$subj

		# convert functional dicoms to nifti

		cd ref_data
		dcm2niix -o . -z y -f $subj"_%p_%s" ../dicom/$funct

		# get functional filename
		functFile=$(ls $subj*$(expr $funct + 0).nii.gz)
		functFile=$(basename $functFile .nii.gz)

		# deoblique the functional nifti
		3dWarp -deoblique -prefix $functFile'_deobl' $functFile.nii.gz

		# align to the middle volume
		3dvolreg -zpad 4 -prefix $functFile"_vr" -dfile $functFile"_vr.1D" -base $functFile"_deobl"+orig\[87\] -verbose $functFile"_deobl"+orig   

		# Inspect the motion correction parameters:
		# less 0003_t1_mprage_sag_p2_iso_5_vr.1D
		# 1dplot 0003_t1_mprage_sag_p2_iso_5_vr.1D &

		# Some housekeeping:
		cd ..
		mv ref_data/$functFile"_vr"+orig.* reg_data/
		mv ref_data/$functFile"_vr.1D" params/
		cp analysis/$t1_scan'_deobl'+orig.* reg_data/
		cd reg_data

		# Align the EPI data to the anatomical:
		
		align_epi_anat.py -anat $t1_scan'_deobl'+orig -epi $functFile"_vr"+orig -epi_base mean -epi2anat -volreg off -tshift off -deoblique off -verb 2 -save_vr

		### SMOOTHING ###
		for smooth in ${smooths[@]}; do
			# smoothing (repeat for 2,4,6,8 mm FWHM smoothing)
			3dmerge -1blur_fwhm $smooth -doall -prefix $subj'_FPO_localizer_0'$(expr $funct + 0)'_sm'$smooth'_norm+orig' $functFile"_vr_al"+orig		

		done
	
	done

done