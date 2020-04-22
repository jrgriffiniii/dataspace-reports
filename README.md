# DataSpace Reports

This repository is in place in order to provide for report-generating tasks for
DataSpace.

## Usage

First, please cache the existing DataSpace community and collection structure:
```bash
bundle exec thor dataspace:reports:cache
```

Then, please provide a decompressed directory of a DataSpace export for the
Senior Theses collections for a specific year. This should be placed in
the `exported/` directory. One may then generate the report:

```bash
bundle exec thor dataspace:reports:transform ./exported/senior-thesis-2019/
```

This will generate the necessary collection XML files into the directory
`output/collections`. These must be compressed into a TAR for distribution.
