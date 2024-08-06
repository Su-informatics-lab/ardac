import React, { Fragment } from 'react';
import MolecularBoxplot from './MolecularBoxplot';
import MolecularLineChart from './MolecularLineChart';

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
              data: res
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
        <div>
            {this.state.data && <div className="summary-chart-group" style={{height:'fit-content', minHeight:400}}>
              {this.state.labTestTypes.length>0 && this.state.labTestTypes.map((element, i) => {
                return (
                <Fragment key={i}>
                  <MolecularBoxplot
                    casecount={this.props.casecount}
                    tab={'lab_results'}
                    data={this.state.data}
                    category={'case_arm'}
                    attribute={element}
                    title={element+" Clinicial Trial"}
                  />
                  <MolecularLineChart
                    casecount={this.props.casecount}
                    data={this.state.data}
                    tab={'lab_results'}
                    category={'case_arm'}
                    title={element+" Clinicial Trial"}
                    attribute={element}
                  />
                  <MolecularBoxplot
                    casecount={this.props.casecount}
                    tab={'lab_results'}
                    data={this.state.data}
                    category={'case_group'}
                    attribute={element}
                    title={element+" Observational Study"}
                  />
                  <MolecularLineChart
                    casecount={this.props.casecount}
                    data={this.state.data}
                    tab={'lab_results'}
                    category={'case_group'}
                    attribute={element}
                    title={element+" Observational Study"}
                  />
              </Fragment>)
              })}
              </div> }
          </div>
        )
    }
}
