docker exec -it tube-service bash -c "cd /tmp/datadictionary && pip install ."
docker exec -it tube-service bash -c "cp /usr/share/gen3/tube/dev/dd_mod.py /tube/tube/utils/dd.py " 

