import React from 'react';
import ReactECharts from 'echarts-for-react'; 

import {patVisitEgfrPair, MolecularTestLineData} from './mathworks'

var option = {
  xAxis: {
    name:'Visit_day',
  },
  yAxis: {
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
      option: option,
      visible: true
    };
  }
  componentDidMount(){
    if(this.props.casecount > 0) {
      this.fetchData(this.props.casecount)
    }
  }
  componentWillUnmount() {
    // fix Warning: Can't perform a React state update on an unmounted component
    this.setState = (state,callback)=>{
        return;
    };
  }

  updateSeries(data){
    if(data[0].length==0) {
      this.setState({visible: false})
    } else this.setState({visible: true})
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
        series : this.state.series,
        yAxis: {name: this.props.attribute}
      }
    });
    // console.log("Stacked", JSON.stringify(this.state.series))
  }

  fetchData(casecount){
    const size = casecount
    const offset = 0
    const sort = []
    this.props.fetchAndUpdateRawData({
      offset, size, sort
    }).then((res) => {
      if(this.props.tab=='lab_results')
      this.updateSeries(MolecularTestLineData(res, 'pat_id', this.props.attribute, this.props.category))
      else
        this.updateSeries(patVisitEgfrPair(res, 'pat_id', this.props.attribute, this.props.category))
    });
  };

  componentWillReceiveProps(nextProps){
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
      <>
      {this.state.visible && <div className="summary-chart-group__column">
        <div className='summary-chart-group__column-left-border'></div>
        <div className='summary-horizontal-bar-chart'>
          <div className='exploration_chart__title-box'>
            <p className='exploration-chart__title'>{this.props.title}</p>
          </div>
            {/* {JSON.stringify(this.getOption())} */}
            <ReactECharts
                style={{width: 400, height: 300}}
                option={this.getOption()}
                notMerge={true}
                lazyUpdate={true}
                theme={"theme_name"}
              />
          </div>
      </div>}
    </>
    )
  }
}
export default StackedLineChart