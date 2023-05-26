import React from 'react';
import ReactECharts from 'echarts-for-react'; 

import {SexAgeEgfrPair} from './mathworks'

var option = {
    title: {
      text: 'Basic Radar Chart'
    },
    legend: {
      data: ['Allocated Budget', 'Actual Spending'],
      x:'center',
      y:'bottom',
      grid:{
        bottom: '7%'
      }
    },
    radar: {
      // shape: 'circle',
      indicator: [
        { name: 'Sales', max: 6500 },
        { name: 'Admin', max: 16000 },
        { name: 'Tech', max: 30000 },
        { name: 'Customer Support', max: 38000 },
        { name: 'Develop', max: 52000 },
        { name: 'Marketing', max: 25000 }
      ]
    },
    series: [
      {
        name: 'Budget vs spending',
        type: 'radar',
        data: [
          {
            value: [4200, 3000, 20000, 35000, 50000, 18000],
            name: 'Allocated Budget'
          },
          {
            value: [5000, 14000, 28000, 26000, 42000, 21000],
            name: 'Actual Spending'
          }
        ]
      }
    ]
  };

class RadarChart extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      series: [],
      option: option
    };
  }

  updateSeries(data){
    const newSeries = []
    for (var i = 0; i < data[1].length; i++){
      newSeries.push({
        name: data[0][i],
        data: data[1][i],
        type: 'line'
      })
    }
    this.setState({
      series:newSeries
    }, ()=>{
      this.state.option = {
        ...this.state.option,
        series : this.state.series}
      
    });
  }

  fetchData(casecount){
    const size = casecount
    const offset = 0
    const sort = []
    this.props.fetchAndUpdateRawData({
      offset, size, sort
    }).then((res) => {
      this.updateSeries(SexAgeEgfrPair(res, 'race'))
    });
  };

  componentWillReceiveProps(nextProps){
    // console.log(this.props.casecount+'+'+nextProps.casecount)
    if(this.props.casecount !== nextProps.casecount){
      if(nextProps.casecount>0){
        this.fetchData(nextProps.casecount)
      }
    }
  }

  getOption(){
    option = {
      ...this.state.option,
      series : this.state.series
    }
    return option
  }

  render() {
    return (
        <div>
          {/* {JSON.stringify(this.getOption())} */}
          <ReactECharts
              style={{width: 370, height: 350}}
              option={option}
              notMerge={true}
              lazyUpdate={true}
              theme={"theme_name"}
            />
        </div>
    )
  }
}
export default RadarChart