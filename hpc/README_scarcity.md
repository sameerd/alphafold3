# Running Alphafold3 on scarcity




## Creating Alphafold3 mamba environment

```shell
mamba create -n AF3 python==3.11
mamba activate AF3
mamba install -c bioconda hmmer==3.4
mamba install -c conda-forge zstd wget gcc gxx cmake

# need to install zlib headers manually for cifpp
# this header is already installed in $CONDA_PREFIX/include
# but somehow the conda gcc doesnt pick itup automatically
# We could include that directory but ended up building from scratch
# and linking in the alphafold3/include and alphafold3/lib directories
# EDITED: ../CMakeLists.txt to add these two directories
git clone git@github.com:madler/zlib.git
./configure; make test
make install prefix=$HOME/software/alphafold3/hpc

cd ~/software/alphafold3
pip3 install -r dev-requirements.txt

# pip build weel is not adding the file
# ../src/alphafold3/test_data/featurised_example.pkl to the alphafold3 wheel
# ERROR was:
# sent = os.sendfile(outfd, infd, offset, blocksize)
#        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^       
# BlockingIOError: [Errno 11] Resource temporarily unavailable: 
# 'src/alphafold3/test_data/featurised_example.pkl' -> 
# '/tmp/tmp4euwqy06/wheel/platlib/alphafold3/test_data/featurised_example.pkl'
# EDITED: ../pyproject.toml to eliminate this featurised_example.pkl
# and then build
pip3 install --no-deps .

# now copy featurised_example.pkl manually to the install directory
ALPHAFOLD_INSTALL_LOCATION=`python -c "import alphafold3; print(alphafold3.__file__)"`
cp src/alphafold3/test_data/featurised_example.pkl  \
	`dirname $ALPHAFOLD_INSTALL_LOCATION`/test_data

# Build chemical components database
build_data

# Since we have a CUDA capability 7 gpu we need this flag
# We use conda instead of mamba in the command below as mamba doesnt
# implement this feature yet
conda env config vars set XLA_FLAGS="--xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
# for later capability GPUs we can set the flag below
# XLA_FLAGS="--xla_gpu_enable_triton_gemm=false"
# reactivate the environment to get the environment variable to get set
mamba deactivate
mamba activate AF3

```
