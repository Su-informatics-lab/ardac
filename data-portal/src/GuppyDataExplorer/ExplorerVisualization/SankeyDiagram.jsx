import React from 'react';

import { ResponsiveSankey } from '@nivo/sankey'
const data = {
    "nodes": [
      {
        "id": "Biospecimens",
        "nodeColor": "hsl(234, 70%, 50%)"
      },
      {
        "id": "Lab",
        "nodeColor": "hsl(339, 70%, 50%)"
      },
      {
        "id": "Jane",
        "nodeColor": "hsl(123, 70%, 50%)"
      },
      {
        "id": "Marcel",
        "nodeColor": "hsl(313, 70%, 50%)"
      },
      {
        "id": "Study",
        "nodeColor": "hsl(318, 70%, 50%)"
      },
      {
        "id": "Junko",
        "nodeColor": "hsl(41, 70%, 50%)"
      }
    ],
    "links": [
      {
        "source": "Ibrahim",
        "target": "Jane",
        "value": 122
      },
      {
        "source": "Ibrahim",
        "target": "Marcel",
        "value": 129
      },
      {
        "source": "Ibrahim",
        "target": "John",
        "value": 105
      },
      {
        "source": "Ibrahim",
        "target": "Raoul",
        "value": 129
      },
      {
        "source": "Marcel",
        "target": "Junko",
        "value": 12
      },
      {
        "source": "Marcel",
        "target": "Jane",
        "value": 120
      },
      {
        "source": "Marcel",
        "target": "Raoul",
        "value": 38
      },
      {
        "source": "Jane",
        "target": "Raoul",
        "value": 99
      },
      {
        "source": "Jane",
        "target": "John",
        "value": 93
      },
      {
        "source": "Junko",
        "target": "Jane",
        "value": 49
      },
      {
        "source": "Raoul",
        "target": "John",
        "value": 90
      }
    ]
  }

// make sure parent container have a defined height when using
// responsive component, otherwise height will be 0 and
// no chart will be rendered.
// website examples showcase many properties,
// you'll often use just a few of them.
export const MyResponsiveSankey = () => (
    <ResponsiveSankey
        data={data}
        margin={{ top: 40, right: 160, bottom: 40, left: 50 }}
        align="justify"
        colors={{ scheme: 'category10' }}
        nodeOpacity={1}
        nodeHoverOthersOpacity={0.35}
        nodeThickness={18}
        nodeSpacing={24}
        nodeBorderWidth={0}
        nodeBorderColor={{
            from: 'color',
            modifiers: [
                [
                    'darker',
                    0.8
                ]
            ]
        }}
        nodeBorderRadius={3}
        linkOpacity={0.5}
        linkHoverOthersOpacity={0.1}
        linkContract={3}
        enableLinkGradient={true}
        labelPosition="outside"
        labelOrientation="vertical"
        labelPadding={16}
        labelTextColor={{
            from: 'color',
            modifiers: [
                [
                    'darker',
                    1
                ]
            ]
        }}
        legends={[
            {
                anchor: 'bottom-right',
                direction: 'column',
                translateX: 130,
                itemWidth: 100,
                itemHeight: 14,
                itemDirection: 'right-to-left',
                itemsSpacing: 2,
                itemTextColor: '#999',
                symbolSize: 14,
                effects: [
                    {
                        on: 'hover',
                        style: {
                            itemTextColor: '#000'
                        }
                    }
                ]
            }
        ]}
    />
)

