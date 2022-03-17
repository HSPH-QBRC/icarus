exports = async function(){
  const collection = context.services.get("mongodb-atlas").db("covid").collection("counties");
  const counties = context.values.get("counties");
  for (let fipsCode in counties) {
    console.log(`Loading ${counties[fipsCode]} county`);
    const request = {
      url: `${context.values.get("covidActNowApiBaseUrl")}/county/${fipsCode}.timeseries.json?apiKey=${context.values.get("covidActNowApiKey")}`
    };
    const response = await context.functions.execute("getJsonApiData", request);
    if (response["actualsTimeseries"].length !== response["metricsTimeseries"].length) {
      console.warn(`Number of entries in actualsTimeseries (${response["actualsTimeseries"].length}) does not match metricsTimeseries (${response["metricsTimeseries"].length})`);
    }

    const updates = response["actualsTimeseries"].map(actuals => {
      const metrics = response["metricsTimeseries"].find(element => element["date"] === actuals["date"]);
      if (metrics === undefined) {
        throw new Error(`No metrics found for date: ${actuals["date"]}`);
      }
      return {
        "replaceOne": {
          "filter": {
            "date": new Date(actuals["date"]),
            "fips": fipsCode,
          },
          "replacement": {
            "date": new Date(actuals["date"]),
            "fips": fipsCode,
            "name": counties[fipsCode],
            "newCases": actuals["newCases"],
            "positiveTests": actuals["positiveTests"],
            "negativeTests": actuals["negativeTests"],
            "vaccinesDistributed": actuals["vaccinesDistributed"],
            "vaccinationsInitiated": actuals["vaccinationsInitiated"],
            "vaccinationsCompleted": actuals["vaccinationsCompleted"],
            "caseDensity": metrics["caseDensity"],
            "infectionRate": metrics["infectionRate"],
            "vaccinationsInitiatedRatio": metrics["vaccinationsInitiatedRatio"],
            "vaccinationsCompletedRatio": metrics["vaccinationsCompletedRatio"],
            "testPositivityRatio": metrics["testPositivityRatio"],
          },
          "upsert": true
        }
      };
    })
    await collection.bulkWrite(updates);
  }
};
