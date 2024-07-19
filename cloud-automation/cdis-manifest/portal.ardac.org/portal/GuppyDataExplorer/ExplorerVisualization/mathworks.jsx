export const getRawdata = (rawdata) => {
    return rawdata.data
}

export const SexAgeEgfrPair = (data, column) =>{
    data = getRawdata(data)
    const unique = [...new Set(data.map(item => item[column]))]; 
    var res = []

    unique.forEach(element => {
        const elementdata = []
        for(let i in data){
            if(data[i][column]==element){
                elementdata.push([data[i].age_at_index, data[i].eGFR])
            }
        }
        res.push(elementdata)
    })

    res.forEach(element => {
        element.sort(function(x, y){
            return x[0]-y[0];
          });
    })

    return [unique, res]
}

export const patVisitEgfrPair = (data, column) =>{
    data = getRawdata(data)
    const unique = [...new Set(data.map(item => item[column]))]; 
    var arm = []
    var res = []

    unique.forEach(element => {
        const elementdata = []
        for(let i in data){
            if(data[i][column]==element){
                if(data[i].actarm == null) arm.push("no data")
                else arm.push(data[i].actarm)
                elementdata.push([data[i].visit_day, data[i].eGFR])
            }
        }
        res.push(elementdata)
    })

    res.forEach(element => {
        element.sort(function(x, y){
            return x[0]-y[0];
          });
    })

    return [arm, res]
}


export const EGFRbySex = (data) => {
    data = getRawdata(data)
    const maledata = []
    const femaledata = []
    const nodata = []
    for(let i in data){
        if(data[i].gender=='Male'){
            maledata.push(data[i].eGFR)
        } else if(data[i].gender=='Female'){
            femaledata.push(data[i].eGFR)
        } else 
            nodata.push(data[i].eGFR)
    }

    const maleStat = findMaxMinMed(maledata)
    const femaleStat = findMaxMinMed(femaledata)

    const dataInsert = [
        {
          x: 'Male',
          y: maleStat
        },
        {
            x: 'Female',
            y: femaleStat
        },
        {
            x: 'Unavailable',
            y: [0, 0, 0, 0, 0]
        }
      ]
    return dataInsert
}

const quantile = (arr, q) => {
    const asc = arr => arr.sort((a, b) => a - b);
    const sorted = asc(arr);
    const pos = (sorted.length - 1) * q;
    const base = Math.floor(pos);
    const rest = pos - base;
    if (sorted[base + 1] !== undefined) {
        return sorted[base] + rest * (sorted[base + 1] - sorted[base]);
    } else {
        return sorted[base];
    }
};

const q25 = arr => quantile(arr, .25);

const q50 = arr => quantile(arr, .50);

const q75 = arr => quantile(arr, .75);

export const findMaxMinMed = (data) =>{
    
    data.sort((a, b) => {
        return a - b
    })
    const min = data[0]
    const max = data[data.length-1]

    const med = q50(data);
    const Q1 = q25(data);
    const Q2 = q75(data);
    return [min, Q1, med, Q2, max]
}
