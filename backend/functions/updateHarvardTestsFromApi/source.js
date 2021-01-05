exports = async function() {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("harvard");
  const request = {
    url: context.values.get("prodHarvardCovidTestingApiUrl"),
    headers: { "X-Api-Key": [context.values.get("prodHarvardCovidTestingApiKey")] }
  };

  let tests;
  try {
    tests = await context.functions.execute("getJsonApiData", request);
  } catch (err) {
    console.error(err);
    return;
  }

  tests.daily_data.forEach(test => {
    test.date = new Date(test.date);
    collection.replaceOne({ "date": test.date }, test, { "upsert": true })
      .then(result => {
        if (result.matchedCount && result.modifiedCount) {
          console.log(`Updated testing record for ${test.date}`);
        } else if (result.upsertedId) {
          console.log(`Added testing record for ${test.date}`);
        } else {
          console.log(`Skipping record update for ${test.date}`);
        }
      })
      .catch(err => console.error(`Failed to update items: ${err}`));
  });
};
