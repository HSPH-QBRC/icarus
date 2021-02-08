exports = async function(){
  const collection = context.services.get("mongodb-atlas").db("covid").collection("states");
  for (const state of context.values.get("states")) {
    console.log(`Loading ${state}`);
    const request = {
      url: `${context.values.get("covidActNowApiBaseUrl")}/state/${state}.timeseries.json?apiKey=${context.values.get("covidActNowApiKey")}`
    };
    const response = await context.functions.execute("getJsonApiData", request);
    if (response["actualsTimeseries"].length != response["metricsTimeseries"].length) {
      throw new Error(`Number of entries in actualsTimeseries (${response["actualsTimeseries"].length}) does not match metricsTimeseries (${response["metricsTimeseries"].length})`);
    }

    const updates = response["actualsTimeseries"].map((actuals, index) => {
      metrics = response["metricsTimeseries"][index];
      if (actuals["date"] != metrics["date"]) {
        throw new Error(`Actuals date (${actuals["date"]}) does not match metrics date (${metrics["date"]})`);
      }
      return {
        "replaceOne": {
          "filter": {
            "date": new Date(actuals["date"]),
            "name": state,
          },
          "replacement": {
            "date": new Date(actuals["date"]),
            "name": state,
            "newCases": actuals["newCases"],
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
