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
    def compare(d1, d2):
        
        if d1 == d2:
            print('Same dictionary')
            return
        else:
            print('Different dictionary')

        print()
        
        keys1 = d1.keys()
        keys2 = d2.keys()

        print(f'# yamls in d1 = {len(keys1)}')
        print(f'# yamls in d2 = {len(keys2)}')
        print()
        
        kset = list(keys1 - keys2)
        if len(kset) > 0:
            print('yamls in d1 but not in d2')
            print(kset)
            print()
            
        kset = list(keys2 - keys1)
        if len(kset) > 0:
            print('yamls in d2 but not in d1')
            print(kset)
            print()
        
        print('Checking common yamls both in d1 and d2')
        print('Following comparison (add/remove/update) is using d1 as reference')
        print()
        
        commonKeys = set(keys1).intersection(set(keys2))
        
        cnt = 0
        for key in commonKeys:
            yaml1 = d1[key]
            yaml2 = d2[key]

            if yaml1 != yaml2:
                print(f'!!!, yaml "{key}" is different')
                diff = DeepDiff(d1[key], d2[key])
                print('-------- Difference details --------')
                print(diff)
                print()
                cnt += 1
            else:
                #pass
                print(f'OK, yaml "{key}" is same')
                print()

        print(f'Within common yamls, total # yamls that are different: {cnt}')    

        print()


# In[ ]:


def compareDict(dirName):

    pattern = os.path.join(dirName, "*.json")

    files = glob(pattern)

    if len(files) != 2:
        print(f"Expect to see exactly TWO dictionary json files to compare, actual got {len(files)}, exit.")
        return
    
    d1 = DictionaryUtilies.load_dict_json(files[0])

    d2 = DictionaryUtilies.load_dict_json(files[1])

    basename = os.path.basename(files[0])
    print(f'Referring file {basename} as d1')

    basename = os.path.basename(files[1])
    print(f'Referring file {basename} as d2')

    print()
    
    DictionaryUtilies.compare(d1, d2)

    print('Processing complete')


# In[ ]:


def main():
    parser = argparse.ArgumentParser(
        description = 'Compare two dictionary jsons'
    )

    parser.add_argument('-dirpath', '--dirpath', type = str, action = 'store', help = 'Path of the directory where two dictionary json files can be located', \
                        required = True)

    args = parser.parse_args()

    compareDict(args.dirpath)


# In[ ]:


if __name__ == '__main__':
    main()

