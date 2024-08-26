# Dictionary utilities
The code in this directory can be used to build a Docker container that can be used to validate a dictionary against the GDC dictionary schema. The code can also be used to decompose a dictionary JSON file into schema YAML files, and to compare two dictionary JSON files.

> [!NOTE]
> In following examples, the assumption is that you are using `dictutils` as the container name

# Build the docker image
```
docker build --no-cache --progress=plain --rm -t dictutils .
```

# Validate the schema
```
docker run --rm -v $(pwd):/mnt/host dictutils
```
> [!NOTE]
> This expects to find `gdcdictionary/schemas/*.yaml` in your current directory. If you run this from another location that is not your dictionary repo, replace `$(pwd)` with the full path, e.g.: `/path/to/your/dictionary`.

Upon passing all checks, `artifacts/schema.json` will be generated under the specified folder.

# Reverse engineer a schema JSON file into YAML files for your data model
```
docker run --rm -v $(pwd):/mnt/host dictutils /bin/bash -c "/app/json2yml.sh"
```
> [!NOTE]
> This expects to find a JSON schema file in your current directory. Otherwise, replace `$(pwd)` with the full path, e.g.: `/path/to/your/schema.json`.

Upon completion, a folder named `yamls` will be created under the specified folder with the YAML files.

# Compare two dictionary json files
```
docker run --rm -v $(pwd):/mnt/host dictutils /bin/bash -c "/app/dictcompare.sh"
```
> [!NOTE]
> This expects to find two JSON schema files in your current directory. Otherwise, replace `$(pwd)` with the full path to another location, e.g.: `/path/to/your/schema_files`.

The output details the comparison results.
