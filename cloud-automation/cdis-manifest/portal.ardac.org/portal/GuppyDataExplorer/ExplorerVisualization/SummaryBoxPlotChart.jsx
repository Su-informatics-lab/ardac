import React, {Component} from "react"
import ApexCharts from 'react-apexcharts';

import {EGFRbySex} from './mathworks'


var options = {
  chart: {
    id:'chart1',
    type: 'boxPlot',
    height: 300
  },
  title: {
    text: 'Basic BoxPlot Chart',
    align: 'left'
  },
  plotOptions: {
    boxPlot: {
      colors: {
        upper: '#5C4742',
        lower: '#A5978B'
      }
    }
  }
}

class SummaryBoxplotChart extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      series: [
        {
          type: 'boxPlot',
          data: []
        }
      ],
      totalCount: this.props.totalCount,
      data: [],
      ref: null
    };
  }

  fetchData(casecount){
    const series = this.state.series
    const size = casecount
    const offset = 0
    const sort = []
    this.props.fetchAndUpdateRawData({
      offset, size, sort
    }).then((res) => {
      this.updateSeries(EGFRbySex(res))
    });
  };
  ApexCharts = window.ApexCharts;

  updateSeries(data){
    const newSeries = [];
    this.state.series.forEach((s, idx) => {
      newSeries.push({type: s.type , data:[]});
      data.forEach(one => {
        newSeries[idx].data.push(one)
      })
    });
    this.setState({
      series:newSeries
    }, ()=>{
      this.ApexCharts.exec('chart1', 'updateSeries', 
        newSeries, true)
        window.dispatchEvent(new Event('resize'))
    });
  }
  
  // shouldComponentUpdate(nextProps, nextState){
  //   // if(!this.state.series === nextState.series){  
  //   //   console.log(JSON.stringify(this.state.series))
  //   //   console.log(JSON.stringify(nextState.series))
  //   //   return true
  //   // }
      
  //   if(this.props.casecount !== nextProps.casecount){
  //     return true
  //   } else 
  //     return false
  // }
   
  componentWillReceiveProps(nextProps){
    // console.log(this.props.casecount+'+'+nextProps.casecount)
    if(this.props.casecount !== nextProps.casecount){
      if(nextProps.casecount>0){
        this.fetchData(nextProps.casecount)
      }
    }
  }

  componentWillUpdate (nextProps,nextState) {
    const ApexCharts = window.ApexCharts;
    this.ApexCharts.exec('chart1', 'updateSeries', 
        nextState.series, true)
  }

  chartRef(ref) {
    if (ref) {
      this.setState({ref:ref})
    }
  }
  render() {
    return (
        <div id="chart">
            <ApexCharts 
              ref='chart1' 
              id='chart1' 
              options={options} 
              series={this.state.series} 
              type="boxPlot" height={300} />
        </div>
    )
  }
}
export default SummaryBoxplotChart