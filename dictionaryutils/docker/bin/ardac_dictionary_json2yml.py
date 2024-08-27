#!/usr/bin/env python
# coding: utf-8

# In[ ]:


import sys
import json
from pathlib import Path
import os
import yaml
from glob import glob
import argparse

from deepdiff import DeepDiff


# In[ ]:


class DictionaryUtilies:
    
    @staticmethod
    def load_dict_json(filepath):
        with open(filepath) as f:
            # returns JSON object as  
            # a dictionary 
            d = json.load(f) 
        
        return d 
            
    @staticmethod
    def dict2schemas(dictionary):
        
        schemas = {}
        
        for key in dictionary:
        
            schemas[key] = yaml.dump(dictionary[key], default_flow_style=False)
            
        return schemas
    
    @staticmethod
    def saveSchemas(schemas, outdir):
    
        Path(outdir).mkdir(parents = True, exist_ok = True)
        
        for key in schemas:
            schema = schemas[key]
            
#             print(f'Emitting schema {key}')
            
            filepath = os.path.join(outdir, key)
            with open(filepath, 'w') as f:
                f.write(schema)      


# In[ ]:


def json2Yamls(dirName):

    pattern = os.path.join(dirName, "*.json")

    files = glob(pattern)

    if len(files) != 1:
        print(f"Expect to see only ONE dictionary json file, actual got {len(files)}, exit.")
        return

    filepath = files[0]

    d = DictionaryUtilies.load_dict_json(filepath)

    schemas = DictionaryUtilies.dict2schemas(d)

    outdir = os.path.join(dirName, 'gdcdictionary', 'schemas')
    DictionaryUtilies.saveSchemas(schemas, outdir) 

    print('Processing complete')


# In[ ]:


def main():
    parser = argparse.ArgumentParser(
        description = 'Dictionary json 2 yaml schemas'
    )

    parser.add_argument('-dirpath', '--dirpath', type = str, action = 'store', help = 'Path of the directory where dictionary json can be located', \
                        required = True)

    args = parser.parse_args()

    json2Yamls(args.dirpath)


# In[ ]:


if __name__ == '__main__':
    main()

