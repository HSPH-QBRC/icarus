exports = async function(payload, response) {
  // aggregate data from different collections by ISO week for downstream analyses
  const database = context.services.get("mongodb-atlas").db("covid");
  const locations = {
    "bostoncollege": {
      "metro": "Boston-Cambridge-Newton, MA-NH",
      "county": "Middlesex",
      "state": "MA"
    },
    "harvard": {
      "metro": "Boston-Cambridge-Newton, MA-NH",
      "county": "Middlesex",
      "state": "MA"
    }
  };
  let csv = [
    "school,week,county_positive,county_density,county_vaccine,state_positive,state_density,state_vaccine,metro_positive,metro_density,metro_vaccine,positive,total"
  ];

  for (const school in locations) {
    const collection = database.collection(`${school}.weekly`);
    const pipeline = [
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
      }, {
        '$project': {
          'tests': 1, 
          'positives': 1, 
          'county': {
            '$filter': {
              'input': '$counties', 
              'as': 'county', 
              'cond': {
                '$eq': [
                  '$$county._id.name', locations[school].county
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
                  '$$state._id.name', locations[school].state
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
                  '$$metro._id.name', locations[school].metro
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
    ];
    const results = await collection.aggregate(pipeline).toArray();
  
    for (const entry of results) {
      const row = [
        school, entry._id.week,
        entry.county.positives, entry.county.density, entry.county.vaccinations,
        entry.state.positives, entry.state.density, entry.state.vaccinations,
        entry.metro.positives, entry.metro.density, entry.metro.vaccinations,
        entry.positives, entry.tests
      ];
      csv.push(row.join(","));
    }
  }

  response.setStatusCode(200);
  response.setHeader("Content-Type", "text/csv");
  response.addHeader("Content-Disposition", 'attachment; filename="isoweeks.csv"');
  response.setBody(csv.join("\n"));
  // return csv.join("\n");
};
