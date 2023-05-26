import React from 'react';
import ReactECharts from 'echarts-for-react'; 

import {SexAgeEgfrPair, patVisitEgfrPair} from './mathworks'

var option = {
  xAxis: {
    name:'Visit_day',
    min: 15
  },
  yAxis: {
    name:'eGFR'
  },
  series: [
    {
      type: 'line',
      symbol:'none'
    }
  ],
  legend: {

  }
};

class StackedLineChart extends React.Component {
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
        type: 'line',
        symbol: 'none'
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
      this.updateSeries(patVisitEgfrPair(res, 'submitter_id'))
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
              style={{width: 400, height: 300}}
              option={this.getOption()}
              notMerge={true}
              lazyUpdate={true}
              theme={"theme_name"}
            />
        </div>
    )
  }
}
export default StackedLineChart