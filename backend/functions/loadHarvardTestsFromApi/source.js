exports = async function(start_date = "2020-01-01") {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("harvard");
  const request = {
    url: `${context.values.get("prodHarvardCovidTestingApiUrl")}?start_date=${start_date}`,
    headers: { "X-Api-Key": [context.values.get("prodHarvardCovidTestingApiKey")] }
  };

  let tests;
  try {
    tests = await context.functions.execute("getJsonApiData", request);
    tests.daily_data.forEach(test => test.date = new Date(test.date));
  } catch (err) {
    console.error(err);
    return;
  }

  collection.insertMany(tests.daily_data)
    .then(result => console.log(`Successfully inserted ${result.insertedIds.length} items!`))
    .catch(err => console.error(`Failed to insert documents: ${err}`));
};
