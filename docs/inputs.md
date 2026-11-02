# Upstream data

`quota_assignment` reads versioned inputs from upstream repositories. Shared
source files and preparations belong upstream; assignment models, diagnostics,
and reports belong here. The Weaver files are already public in
[local_elections_up](https://github.com/in-rolls/local_elections_up/tree/main/data/reference/weaver).
They are not a private dependency of this analysis.

## Repository checkouts

Create these sibling checkouts in a new working directory. The commands pin
commits without changing any existing checkout. `quota_assignment` reads the
files directly and verifies their SHA-256 hashes before analysis.

```sh
git clone https://github.com/in-rolls/quota_assignment.git
git clone https://github.com/in-rolls/local_elections.git
git -C local_elections checkout --detach 112e86b749257aba5b10106f5727e36019e924f4
git clone https://github.com/in-rolls/local_elections_up.git
git -C local_elections_up checkout --detach 4c84846114cebddda944e0a4947eaae1aaec47ae
git clone https://github.com/in-rolls/local_elections_rajasthan.git
git -C local_elections_rajasthan checkout --detach 8bfdf8123296b451336a28b1fb054217c4f263ee
git clone https://github.com/in-rolls/quota_sanitation.git
git -C quota_sanitation checkout --detach 6e1b2caf55b5a96c0793fb754271a79ce5a48a94
```

The dependencies are:

- `local_elections`: Rajasthan and UP master election panels for `make analysis`.
- `local_elections_up`: the official UP village–GP mapping, Weaver's March 17,
  2025 source file, and its prepared wide panel for `make caste`. The source and
  panel hashes match the public upstream Git objects. Attribution and vintage
  definitions live in the upstream
  [Weaver README](https://github.com/in-rolls/local_elections_up/blob/4c84846114cebddda944e0a4947eaae1aaec47ae/data/reference/weaver/README.md).
- `local_elections_rajasthan`: the official Rajasthan village–GP mapping for
  `make caste`.
- `quota_sanitation`: the authors' GP-level assignment predictions for
  `make assignment`. Its data directory is restored from the authors' archive,
  as described below; cloning the repository alone does not supply the data.

The master input hashes are in [source_lock.json](source_lock.json). Census,
LGD and Weaver inputs are in [caste_source_lock.json](caste_source_lock.json).
The prediction audit input is in
[assignment_source_lock.json](assignment_source_lock.json). Repository inputs
record both the upstream commit and the consumed file's hash. A changed hash
stops the build; upstream updates require a deliberate review and repin.

## Author prediction data

Download the Chaturvedi, Das and Mahajan
[replication archive](https://doi.org/10.7910/DVN/Z6RRUE) into the upstream
`quota_sanitation` checkout. The archive is about 1.25 GB. Extract only the
GP-level file consumed by this analysis with `unar`:

```sh
cd quota_sanitation
curl --fail --location --output sarpanch_toilets_replication.rar \
  https://dataverse.harvard.edu/api/access/datafile/7677114
printf '%s\n' 'a03621635795a85f5d997482acda163b  sarpanch_toilets_replication.rar' | md5sum --check
unar -D -o . sarpanch_toilets_replication.rar 'data/final election caste sbm.dta'
cd ../quota_assignment
```

On macOS, `md5 sarpanch_toilets_replication.rar` can check the same archive
checksum. `make assignment` separately verifies the extracted file's SHA-256
against `assignment_source_lock.json`. The archive remains the authoritative
source; this analysis does not maintain a second copy in its Git history.

## SHRUG

Obtain the SHRUG 2.0 Population Census keys and 2001/2011 Population Census
modules from [Development Data Lab](https://www.devdatalab.org/shrug). Retain
these paths under the directory selected by `SHRUG`:

```text
shrug-pc-keys-csv/pc11r_shrid_key.csv
shrug-pc-keys-csv/pc11u_shrid_key.csv
shrug-pca01-csv/pc01_pca_clean_shrid.csv.zip
shrug-pca11-csv/pc11_pca_clean_shrid.csv
```

The build checks all four file hashes. SHRUG remains a separately obtained
upstream dataset, with its own attribution and license terms.

## Run

From `quota_assignment`, the default sibling layout needs no election path
settings. `SHRUG` defaults to `~/data/shrug/2.0`. For another layout, set
`IN_ROLLS` to the directory containing the upstream repositories,
`LOCAL_ELECTIONS` to the master repository checkout, and `SHRUG` to the SHRUG
2.0 directory.

```sh
make restore
make check
make analysis
make caste
make assignment
make tables
```

`make tables` renders saved CSV results with `knitr::kable()`; it does not rerun
estimation. Caste and prediction-audit tables are rendered when their saved
inputs are present, with a message identifying any missing analysis stage.
