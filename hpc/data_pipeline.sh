#!/bin/bash

#set -x
readonly CWD=$PWD
readonly STAGING_DIR=/staging/groups/glbrc_alphafold/af3

DB_DIR_STUB=db
SINGIMG=""

PRINT_INFO=0
function printinfo {
  if [[ "$PRINT_INFO" -ne 0 ]] ; then
    echo $1
  fi
}


while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--printinfo)
      PRINT_INFO=1
      printinfo "Setting printinfo on"
      shift # past argument
      ;;
    -r|--run_in_container)
      SINGIMG="$2"
      printinfo "Will copy container $SINGIMG and run inside it"
      shift # past argument
      shift # past value
      ;;
    --smalldb)
      DB_DIR_STUB=db_small
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done


printinfo "Setting up database : $DB_DIR_STUB"

readonly STAGING_DB_DIR="${STAGING_DIR}/${DB_DIR_STUB}"

mkdir -p work
pushd work

mkdir -p af_input af_output models public_databases

# prepare input directory
mv ../*.json af_input/

## copy the container if we are going to run commands inside it
IMGEXEC="" # default is to not pipe commands through container
if [[ -n "$SINGIMG" ]] ; then
  printinfo "Copying container : $SINGIMG"
  cp "${STAGING_DIR}"/${SINGIMG} .
  IMGEXEC="apptainer exec ${SINGIMG}"
else
  printinfo "Running inside the container : not copying container"
fi

## prepare public_databases directory
## Will do 8 file copy/uncompress in parallel so we request 8 cpus
printinfo "Decompressing pdb_2022_09_28_mmcif_files"
cat "${STAGING_DB_DIR}"/pdb_2022_09_28_mmcif_files.tar.zst | \
        ${IMGEXEC} tar --no-same-owner --no-same-permissions \
        --use-compress-program=zstd -xf - --directory=public_databases/ &

for NAME in mgy_clusters_2022_05.fa \
            bfd-first_non_consensus_sequences.fasta \
            uniref90_2022_05.fa uniprot_all_2021_04.fa \
            pdb_seqres_2022_09_28.fasta \
            rnacentral_active_seq_id_90_cov_80_linclust.fasta \
            nt_rna_2023_02_23_clust_seq_id_90_cov_80_rep_seq.fasta \
            rfam_14_9_clust_seq_id_90_cov_80_rep_seq.fasta ; do
  printinfo "Start decompressing: '${NAME}'"
  cat "${STAGING_DB_DIR}/${NAME}.zst" | \
      ${IMGEXEC} zstd --decompress > "public_databases/${NAME}" &
done

wait
printinfo "Completed database installation"

if [[ -n "$SINGIMG" ]] ; then
  apptainer exec \
    --bind af_input:/root/af_input \
    --bind af_output:/root/af_output \
    --bind models:/root/models \
    --bind public_databases:/root/public_databases \
    --cwd /app/alphafold \
    ${SINGIMG} \
    python run_alphafold.py \
    --db_dir=/root/public_databases \
    --run_data_pipeline=true \
    --run_inference=false \
    --input_dir=/root/af_input \
    --model_dir=/root/models \
    --output_dir=/root/af_output
else
  workdir=`realpath .`
  pushd /app/alphafold
  python run_alphafold.py \
       --db_dir=${workdir}/public_databases \
       --model_dir=${workdir}/models \
       --run_data_pipeline=true \
       --run_inference=false \
       --input_dir=${workdir}/af_input \
       --output_dir=${workdir}/af_output
  popd # back to workdir
fi

popd # back to home dir

# tar up the output directory - one tar for each job. These get returned
shopt -s nullglob # we do not want an empty match below
for output_name in work/af_output/*
do
  output_name_base="${output_name##*/}"
  printinfo "Compressing : $output_name_base"
  tar zcf "${output_name_base}".data_pipeline.tar.gz -C "${output_name}" .
done

# clean up
rm -rf work
rm -rf .bash_history .bashrc .lesshst .viminfo

