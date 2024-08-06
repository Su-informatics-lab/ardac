import React, { Fragment } from 'react';
import SummaryBoxplotChart from './SummaryBoxPlotChart';
import StackedLineChart from './StackedLineChart';

export class MolecularTestTab extends React.Component {
    constructor(props) {
      super(props);
      this.state = {
        labTestTypes : [],
        data:null
      };
    }
    componentDidMount(){
      if(this.props.casecount>0 && this.props.casecount<=10000){
        this.fetchData(this.props.casecount)
      }
    }

    componentWillReceiveProps(nextProps){
        if(this.props.casecount !== nextProps.casecount){
          if(nextProps.casecount>=0 && nextProps.casecount<=10000){
            this.fetchData(nextProps.casecount)
          }
        }
      }

    getLabTestType(data){
        const unique = [...new Set(data.map(item => item['laboratory_test']))];
        console.log(unique) 
        this.setState({
            labTestTypes: unique
        })
    }

    fetchData(casecount){
        const size = casecount
        const offset = 0
        const sort = []
        this.props.fetchAndUpdateRawData({
          offset, size, sort
        }).then((res) => {
            this.getLabTestType(res.data)
            this.setState({
              data: res.data
          })
        });
      };

     componentWillUnmount() {
        // fix Warning: Can't perform a React state update on an unmounted component
        this.setState = (state,callback)=>{
            return;
        };
      }

    render() {
        return (
          console.log(this.state.data),
        <div>
            <div className="summary-chart-group" style={{height:'fit-content', minHeight:400}}>
              {this.state.labTestTypes.length>0 && this.state.labTestTypes.map((element, i) => {
                return (
                <Fragment key={i}>
                  <SummaryBoxplotChart
                    casecount={this.props.casecount}
                    tab={'lab_results'}
                    fetchAndUpdateRawData={this.props.fetchAndUpdateRawData}
                    category={'case_arm'}
                    attribute={element}
                    title={element+" clinicial"}
                  />
                  <StackedLineChart
                    casecount={this.props.casecount}
                    fetchAndUpdateRawData={this.props.fetchAndUpdateRawData}  
                    tab={'lab_results'}
                    category={'case_arm'}
                    title={element+" clinicial"}
                    attribute={element}
                  />
                  <SummaryBoxplotChart
                    casecount={this.props.casecount}
                    tab={'lab_results'}
                    fetchAndUpdateRawData={this.props.fetchAndUpdateRawData}
                    category={'case_group'}
                    attribute={element}
                    title={element+" Obs"}
                  />
                  <StackedLineChart
                    casecount={this.props.casecount}
                    fetchAndUpdateRawData={this.props.fetchAndUpdateRawData}  
                    tab={'lab_results'}
                    category={'case_group'}
                    attribute={element}
                    title={element+" Obs"}
                  />
              </Fragment>)
              })}
              </div> 
          </div>
        )
    }
}
