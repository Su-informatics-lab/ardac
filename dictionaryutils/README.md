# Dictionary utilities

In following examples we assume you use 'dict_validator' as the container name

# to build docker image
docker build --no-cache --progress=plain --rm -t dict_validator .

# to run schema check
docker run --rm -v </path/to/your/local_dir>:/mnt/host dict_validator

where we expect "gdcdictionary/schemas/*.yaml" under your </path/to/your/local_dir>. Upon passing all checks, "artifacts/schema.json" will be generated under the specified folder.

# to decompose a dictionary json into schema yamls 
docker run --rm -v </path/to/your/local_dir>:/mnt/host dict_validator /bin/bash -c "/app/json2yml.sh"

where we expect a json dictionary file under "</path/to/your/local_dir>". Upon completion, a folder named "yamls" will be created under the specified folder to host schema yamls.

# to compare two dictionary json files
docker run --rm -v </path/to/your/local_dir>:/mnt/host dict_validator /bin/bash -c "/app/dictcompare.sh"

where we expect two json dictionary files under "</path/to/your/local_dir>". The output details the comparison results.
