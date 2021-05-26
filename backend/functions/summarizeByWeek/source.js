exports = async function(payload, response) {
  // aggregate data from different collections by ISO week for downstream analyses
  const database = context.services.get("mongodb-atlas").db("covid");
  // join data for each school with data for corresponding geographic areas
  for (const institution of context.values.get("institutions")) {
    const collection = database.collection(`${institution.collection}.weekly`);
    let pipeline = [
      {
        '$lookup': {
          'from': 'counties.weekly',
          'localField': 'week',
          'foreignField': 'week',
          'as': 'counties'
        }
      }, {
        '$lookup': {
          'from': 'states.weekly', 
          'localField': 'week', 
          'foreignField': 'week', 
          'as': 'states'
        }
      }, {
        '$lookup': {
          'from': 'metros.weekly', 
          'localField': 'week', 
          'foreignField': 'week', 
          'as': 'metros'
        }
      }
    ];

    if (["MA public schools", "Boston-area public schools"].includes(institution.name)) {
      pipeline = pipeline.concat([
        {
          '$project': {
            'week': true,
            'tests': true, 
            'positives': true, 
            'counties': {
              '$filter': {
                'input': '$counties', 
                'as': 'county', 
                'cond': {
                  '$or': [
                    {
                      '$eq': [
                        '$$county.name', 'Suffolk'
                      ]
                    }, {
                      '$eq': [
                        '$$county.name', 'Middlesex'
                      ]
                    }
                  ]
                }
              }
            }, 
            'state': {
              '$filter': {
                'input': '$states', 
                'as': 'state', 
                'cond': {
                  '$eq': [
                    '$$state.name', institution.state
                  ]
                }
              }
            }, 
            'metro': {
              '$filter': {
                'input': '$metros', 
                'as': 'metro', 
                'cond': {
                  '$eq': [
                    '$$metro.name', institution.metro
                  ]
                }
              }
            }
          }
        }, {
          '$addFields': {
            'county': {
              'positives': {
                '$sum': '$counties.positives'
              }, 
              'density': {
                '$divide': [
                  {
                    '$sum': '$counties.density'
                  }, 2
                ]
              }, 
              'vaccinations': {
                '$sum': '$counties.vaccinations'
              }
            }
          }
        }, {
          '$project': {
            'counties': false,
          }
        }, {
          '$unwind': {
            'path': '$state'
          }
        }, {
          '$unwind': {
            'path': '$metro'
          }
        }
      ]);
    } else {
      pipeline = pipeline.concat([
        {
          '$project': {
            'week': true,
            'tests': true, 
            'positives': true, 
            'county': {
              '$filter': {
                'input': '$counties', 
                'as': 'county', 
                'cond': {
                  '$eq': [
                    '$$county.name', institution.county
                  ]
                }
              }
            }, 
            'state': {
              '$filter': {
                'input': '$states', 
                'as': 'state', 
                'cond': {
                  '$eq': [
                    '$$state.name', institution.state
                  ]
                }
              }
            }, 
            'metro': {
              '$filter': {
                'input': '$metros', 
                'as': 'metro', 
                'cond': {
                  '$eq': [
                    '$$metro.name', institution.metro
                  ]
                }
              }
            }
          }
        }, {
          '$unwind': {
            'path': '$county'
          }
        }, {
          '$unwind': {
            'path': '$state'
          }
        }, {
          '$unwind': {
            'path': '$metro'
          }
        }
      ]);
    }  // end if

  pipeline = pipeline.concat([
    {
      '$addFields': {
        'school': institution.name
      }
    }, {
      '$merge': {
        into: 'isoweeks',
        on: ['week', 'school'],
        whenMatched: 'replace'
      }
    }
  ]);

  await collection.aggregate(pipeline).toArray();
  }  // end for
};
