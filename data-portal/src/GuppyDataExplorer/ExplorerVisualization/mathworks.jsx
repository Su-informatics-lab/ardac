import { element } from "prop-types";

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

export const MolecularTestLineData = (data, column, attribute, study_category) =>{
    data = getRawdata(data)
    const unique = [...new Set(data.map(item => item[column][0]))]; 
    var res = []
    var arm = []
    unique.forEach(element => {
        const elementdata = []
        var case_arm = null
        for(let i in data){
            if(data[i][column][0]==element){
                if(data[i][study_category] == undefined || data[i][study_category]==null || data[i][study_category].length == 0 ) continue; //arm.push("no data")
                else if(data[i]['laboratory_test']==attribute){            
                    // arm.push(String(data[i][study_category][0]))
                    case_arm = String(data[i][study_category][0])
                    elementdata.push([data[i].visit_day[0], data[i]['test_value']])
                }
            }
        }
        if(elementdata.length!=0 && case_arm!=null){
            arm.push(case_arm)
            res.push(elementdata)
        }
    })
    res.forEach(element => {
        element.sort(function(x, y){
            return x[0]-y[0];
          });
    })
    // if(study_category=='case_arm'){
    //     console.log(arm, res)
    // }
    return [arm, res]
}

export const patVisitEgfrPair = (data, column, attribute, study_category) =>{
    data = getRawdata(data)
    const unique = [...new Set(data.map(item => item[column][0]))]; 
    var res = []
    var arm = []
    unique.forEach(element => {
        const elementdata = []
        var case_arm = null
        for(let i in data){
            if(data[i][column]==element){
                if(data[i][study_category] == undefined || data[i][study_category]==null || data[i][study_category].length == 0 ) continue; //arm.push("no data")
                else if(data[i][attribute]==0 || data[i][attribute]==999 || data[i][attribute]==null) continue;
                else {                
                    // arm.push(String(data[i][study_category][0]))
                    case_arm = String(data[i][study_category][0])
                    elementdata.push([data[i].visit_day, data[i][attribute]])
                }
            }
        }
        if(elementdata.length!=0 && case_arm!=null){
            arm.push(case_arm)
            res.push(elementdata)
        }
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
            y: [10, 20, 30, 40, 50]
        }
      ]
    return dataInsert
}

// Method For getting BoxPlot using 2 variables
export const EGFRbyVisit = (data) => {
    // console.log("Data EGFRbyVisit",data)
    data = getRawdata(data)
    // console.log("dataEGFRbyVisit",data)
    
    const maledata = []
    const femaledata = []
    const nodata = []
    for(let i in data){
        if(data[i].case_arm=='Control'){
            maledata.push(data[i].eGFR)
        } else if(data[i].case_arm=='Intervention'){
            femaledata.push(data[i].eGFR)
        } else 
            nodata.push(data[i].eGFR)
    }

    const maleStat = findMaxMinMed(maledata)
    const femaleStat = findMaxMinMed(femaledata)
    const nodataStat = findMaxMinMed(nodata)

    const dataInsert = [
        {
          x: 'Control',
          y: maleStat
        },
        {
            x: 'Intervention',
            y: femaleStat
        },
        {
            x: 'No Data',
            y: nodataStat
        }
      ]
    // console.log("Data EGFRbyVisit res",dataInsert)
    return dataInsert
}

export const MolecularTestBoxplotData = (data, xcolumn, test_name, category) => {
    data = getRawdata(data)
    var case_groups = [...new Set(data.map(item => item[category][0]))]; 
    case_groups = case_groups.sort().reverse()
    if(case_groups.includes(undefined)){
        case_groups = _.without(case_groups, undefined)
    }
    const unique_visit_og = [...new Set(data.map(item => item[xcolumn][0]))]; 
    var unique_visit = unique_visit_og.sort((a, b) => {
        return a - b
    })
    unique_visit = unique_visit.filter(item => item !== null && item !== undefined )
    const all_elementdata = new Map()
    unique_visit.forEach(element => {
        const elementdata = []
        for(let i in data){
            if(data[i][xcolumn]==element && data[i]['laboratory_test']==test_name && data[i][category].length>0){
                elementdata.push([data[i][category][0], data[i]['test_value']])  
            }
        }
        all_elementdata.set(element, elementdata)
    })
    
    const finalMap = new Map()
    case_groups.forEach(element => {
        finalMap.set(element, [])
    })
    var hasDataFlag = false

    var final_data = []
    for (const [key, value] of all_elementdata.entries()) {
        if(value.length == 0) {
            continue
        } else hasDataFlag = true
        const visitMap = new Map()
        case_groups.forEach(element => {
            visitMap.set(element, [])
        })
        for(var i = 0; i < value.length; i++){
            if(value[i][1]==0 || value[i][1]==999 || value[i][1]==null){ continue }
            visitMap.set(value[i][0], [...visitMap.get(value[i][0]), value[i][1]])
        } 
        case_groups.forEach(element => {
            finalMap.set(element, 
                [...finalMap.get(element), {x:String(key), y:findMaxMinMed(visitMap.get(element))}]
            )
        })
    }
    if (!hasDataFlag) return null
    case_groups.forEach(element => {
        final_data.push({
            name: element,
            data:finalMap.get(element)
        })
    })
    return final_data
}


//  BoxPlot using 3 variables Data of visit_day, Actram and EGFR
export const CombinedbyVisitDays = (data, xcolumn, attribute) => {
    data = getRawdata(data)
    var case_arms = [...new Set(data.map(item => item['case_arm'][0]))]; 
    case_arms = case_arms.sort().reverse()
    if(case_arms.includes(undefined)){
        case_arms = _.without(case_arms, undefined)
    }
    const unique_visit_og = [...new Set(data.map(item => item[xcolumn]))]; 
    var unique_visit = unique_visit_og.sort((a, b) => {
        return a - b
    })
    if(attribute=='lille_score') unique_visit=[7]
    else unique_visit = unique_visit.filter(item => item !== null)
    const all_elementdata = new Map()
    unique_visit.forEach(element => {
        const elementdata = []
        for(let i in data){
            if(data[i][xcolumn]==element && data[i].case_arm.length != 0
                 && data[i][attribute]!=null && data[i].study_name=='clinical_trail_study')
                elementdata.push([data[i].case_arm[0], data[i][attribute]])  
        }
        all_elementdata.set(element, elementdata)
    })
    const group0 = {
        name: case_arms[0],
        data:[]
    }
    const group1 = {
        name: case_arms[1],
        data:[]
    }

    const final_data = []

    for (const [key, value] of all_elementdata.entries()) {
        if(value.length==0) continue;
        const group0Data = []
        const group1Data = []
        for(var i = 0; i < value.length; i++){
            if(value[i][1]==0 || value[i][1]==999) { continue } 
            if(value[i][0]==case_arms[0]){
                group0Data.push(value[i][1])
            } else if(value[i][0]==case_arms[1]){
                group1Data.push(value[i][1])
            }
            else
                group0Data.push(value[i][1])
        } 
        group0.data.push({
            x: String(key),
            y:findMaxMinMed(group0Data)
        })
        group1.data.push({
            x:String(key),
            y:findMaxMinMed(group1Data)
    
        })
    }
    final_data.push(group0)
    final_data.push(group1)

    return final_data
}

export const CombinedbyGroupVisitDay = (data, xcolumn, attribute, category) => {
    data = getRawdata(data)
    var case_groups = [...new Set(data.map(item => item[category][0]))]; 
    case_groups = case_groups.sort().reverse()
    if(case_groups.includes(null)){
        case_groups = _.without(case_groups, null)
    }
    if(case_groups.includes(undefined)){
        case_groups = _.without(case_groups, undefined)
    }
    const unique_visit_og = [...new Set(data.map(item => item[xcolumn]))]; 
    var unique_visit = unique_visit_og.sort((a, b) => {
        return a - b
    })
    if(attribute=='lille_score') unique_visit=[7]
    else unique_visit = unique_visit.filter(item => item !== null)
    const all_elementdata = new Map()
    unique_visit.forEach(element => {
        const elementdata = []
        for(let i in data){
            if(data[i][category].length>0 && data[i][xcolumn]==element && data[i][attribute]!=null){
                elementdata.push([data[i][category][0], data[i][attribute]])  
            }
        }
        all_elementdata.set(element, elementdata)
    })
    
    const finalMap = new Map()
    case_groups.forEach(element => {
        finalMap.set(element, [])
    })
    var hasDataFlag = false
    var final_data = []
    for (const [key, value] of all_elementdata.entries()) {
        if(value.length == 0) {
            continue
        } else hasDataFlag = true
        const visitMap = new Map()
        case_groups.forEach(element => {
            visitMap.set(element, [])
        })

        for(var i = 0; i < value.length; i++){
            if(value[i][1]==0 || value[i][1]==999 || value[i][1]==null){ continue }
            visitMap.set(value[i][0], [...visitMap.get(value[i][0]), value[i][1]])
        } 
        case_groups.forEach(element => {
            finalMap.set(element, 
                [...finalMap.get(element), {x:String(key), y:findMaxMinMed(visitMap.get(element))}]
            )
        })
    }
    if(hasDataFlag==false) return null;
    case_groups.forEach(element => {
        final_data.push({
            name: element,
            data:finalMap.get(element)
        })
    })
    return final_data
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
    data = data.map(Number)
    function checkNum(value) {
        return typeof value === 'number' && !isNaN(value);
    }
    data = data.filter(checkNum)
    data = data.sort((a, b) => {
        return a - b
    })
    const min = data[0]
    const max = data[data.length-1]

    const med = q50(data);
    const Q1 = q25(data);
    const Q2 = q75(data);
    return [min, Q1, med, Q2, max]
}
