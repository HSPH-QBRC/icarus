exports = async function(payload, response) {
  // aggregate data from different collections by ISO week for downstream analyses
  const database = context.services.get("mongodb-atlas").db("covid");
  let csv = [
    "school,week,county_positive,county_density,county_vaccine,state_positive,state_density,state_vaccine,metro_positive,metro_density,metro_vaccine,positive,total"
  ];

  for (const institution of context.values.get("institutions")) {
    const collection = database.collection(`${institution.collection}.weekly`);
    let pipeline = [
      {
        '$lookup': {
          'from': 'counties.weekly', 
          'localField': '_id.week', 
          'foreignField': '_id.week', 
          'as': 'counties'
        }
      }, {
        '$lookup': {
          'from': 'states.weekly', 
          'localField': '_id.week', 
          'foreignField': '_id.week', 
          'as': 'states'
        }
      }, {
        '$lookup': {
          'from': 'metros.weekly', 
          'localField': '_id.week', 
          'foreignField': '_id.week', 
          'as': 'metros'
        }
      }
    ];
    if (["MA public schools", "Boston-area public schools"].includes(institution.name)) {
      pipeline = pipeline.concat([
        {
          '$project': {
            'tests': 1, 
            'positives': 1, 
            'counties': {
              '$filter': {
                'input': '$counties', 
                'as': 'county', 
                'cond': {
                  '$or': [
                    {
                      '$eq': [
                        '$$county._id.name', 'Suffolk'
                      ]
                    }, {
                      '$eq': [
                        '$$county._id.name', 'Middlesex'
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
                    '$$state._id.name', institution.state
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
                    '$$metro._id.name', institution.metro
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
            'tests': 1, 
            'positives': 1, 
            'county': {
              '$filter': {
                'input': '$counties', 
                'as': 'county', 
                'cond': {
                  '$eq': [
                    '$$county._id.name', institution.county
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
                    '$$state._id.name', institution.state
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
                    '$$metro._id.name', institution.metro
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

    const results = await collection.aggregate(pipeline).toArray();
    for (const entry of results) {
      const row = [
        institution.name, entry._id.week,
        entry.county.positives, entry.county.density, entry.county.vaccinations,
        entry.state.positives, entry.state.density, entry.state.vaccinations,
        entry.metro.positives, entry.metro.density, entry.metro.vaccinations,
        entry.positives, entry.tests
      ];
      csv.push(row.join(","));
    }
  }  // end for

  response.setStatusCode(200);
  response.setHeader("Content-Type", "text/csv");
  response.addHeader("Content-Disposition", 'attachment; filename="isoweeks.csv"');
  response.setBody(csv.join("\n"));
};
