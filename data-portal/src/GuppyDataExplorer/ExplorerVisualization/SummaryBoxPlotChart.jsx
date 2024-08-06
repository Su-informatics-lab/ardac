
import React, {Component} from "react"
import ApexCharts from 'react-apexcharts';

import {CombinedbyGroupVisitDay, MolecularTestBoxplotData} from './mathworks'

var options = {
  chart: {
    type: 'boxPlot',
    height: 300,
  },
  xaxis:{
    type: 'numeric',
    title:{
      text:"Visit Days"
    }

  },
  yaxis: {
    type: 'value',
    title: {
      text: 'y_title'
    }
  },
  title: {
    text: 'BoxPlot Chart',
    align: 'left'
  },
  tooltip: {
    shared: false,
    intersect: true
  },
  plotOptions: {
    boxPlot: {
      colors: 
        [ 
          {
            upper: '#E91E63',
            lower: '#A5978B'
          },
          {
            upper: '#9C27B0',
            lower: '#A5978B'
          },
          {
            upper: '#7fcdbb',
            lower: '#A5978B'
          }
        ]
    }
  }
}

class SummaryBoxplotChart extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      series: [
      ],
      totalCount: this.props.totalCount,
      data: [],
      ref: this.props.attribute,
      options: options,
      visible:true
    };
  }
  componentDidMount(){
    this.setState({
      options: {
        ...this.state.options,
        yaxis: {
          type: 'value',
          title: {
            text: this.props.attribute
          }
        },
      }
    })
    if(this.props.casecount > 0) {
      this.fetchData(this.props.casecount)
    }
  }

  fetchData(casecount){
    const size = casecount
    const offset = 0
    const sort = []
    this.props.fetchAndUpdateRawData({
      offset, size, sort
    }).then((res) => {
      if(this.props.tab=='lab_results'){
        this.updateSeries(MolecularTestBoxplotData(res,'visit_day', this.props.attribute, this.props.category))
      } else {
        this.updateSeries(CombinedbyGroupVisitDay(res,'visit_day', this.props.attribute, this.props.category))
        // else
        //   this.updateSeries(CombinedbyVisitDays(res,'visit_day', this.props.attribute, this.props.category))
      }
    });
  };
  ApexCharts = window.ApexCharts;

  updateSeries(data){
    if(data==null) {
      this.setState({visible: false})
      return
    } else this.setState({visible: true})
    this.state.options.yaxis.title.text=this.props.attribute
    this.setState({
      series: data,
    }, ()=>{
      this.ApexCharts.exec(this.props.attribute, 'updateSeries', 
          data, true)
      window.dispatchEvent(new Event('resize'))
    });
  }

   
  componentWillReceiveProps(nextProps){
    if(this.props.casecount !== nextProps.casecount){
      if(nextProps.casecount>0){
        this.fetchData(nextProps.casecount)
      }
    }
  }

  componentWillUpdate (nextProps,nextState) {
    this.ApexCharts.exec(this.props.attribute, 'updateSeries', 
        nextState.series, true)
  }

  componentWillUnmount() {
    // fix Warning: Can't perform a React state update on an unmounted component
    this.setState = (state,callback)=>{
        return;
    };
  }

  chartRef(ref) {
    if (ref) {
      this.setState({ref:ref})
    }
  }

  render() {
    return (
      <>
      {this.state.visible &&
        <div className="summary-chart-group__column summary-horizontal-bar-chart" style={{minWidth: 650}}>
          <div className='exploration_chart__title-box'>
            <p className='exploration-chart__title'>{this.props.title}</p>
          </div> 
          <div id="chart">
                <ApexCharts 
                  ref={this.props.attribute}
                  id={this.props.attribute}
                  options={this.state.options} 
                  series={this.state.series} 
                  type="boxPlot" height={300} width={600} />
            </div>
        </div>
      }
      </>
    )
  }
}
export default SummaryBoxplotChart








