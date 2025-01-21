

## Creating small databases for testing

```
# conda env utils has zstd so activate it
eval "$(micromamba shell hook --shell bash)"
micromamba activate utils


compressed_db_dir=/staging/dcosta2/af3/db

small_db_dir=/staging/dcosta2/af3/db_small
mkdir -p ${small_db_dir}
touch "${small_db_dir}/test.zst"
/bin/rm "${small_db_dir}"/*.zst

pushd "$compressed_db_dir"
for archive in *.zst
do
  echo processing "${archive}"
  zstdcat -d "${archive}" | ~/bin/subsample-fasta -n 1000 | zstd - -o "${small_db_dir}/${archive}"
done
popd



```
