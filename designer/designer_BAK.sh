################################################################################
####                   Execute Designer Pipeline                            ####
####                  Written by Sid on 10/22/2018                          ####
####                  Modified by ___ on XX/XX/XXXX                         ####
####    Changelog:                                                          ####
####      1. Initial creation                                               ####
################################################################################
# To run Designer, open terminal and cd to current dir, then type the command:
#./designer.sh <input dir> <output dir>

# Define input arguments
# input directory needs to contain image.nii, bvals and bvecs
# output directory can be any folder of your choice
input=$1
output=$2

# Run designer
source activate py36
python designer.py \
-denoise -extent 5,5,5 \
-degibbs \
-rician \
-mask \
-prealign \
-smooth 1.25 \
-eddy -rpe_header \
-DKIparams -DTIparams \
${1} ${2}