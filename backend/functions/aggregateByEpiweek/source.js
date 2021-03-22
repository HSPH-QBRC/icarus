exports = async function(){
  // aggregate data from different collections by epiweek for use by Shiny apps
  const mmwr = require("mmwr-week");
  let mdate = new mmwr.MMWRDate();

  const database = context.services.get("mongodb-atlas").db("covid");
  const targetCollection = database.collection("epiweeks");

  let sourceCollection = database.collection("northeastern");
  let sourceDocs = await sourceCollection.find({}, {"Date": 1, "Positive Tests": 1, "Tests Completed": 1})
    .sort({"Date": 1})
    .toArray();

  // add up testing results for each epiweek
  let weeklyResults = new Map();
  for (let entry of sourceDocs) {
    mdate.fromJSDate(new Date(entry["Date"]));
    const epiWeek = mdate.toEpiweek();
    if (weeklyResults.has(epiWeek)) {
      weeklyResults.get(epiWeek).positive += entry["Positive Tests"];
      weeklyResults.get(epiWeek).total += entry["Tests Completed"];
    } else {
      weeklyResults.set(epiWeek, {"positive": entry["Positive Tests"], "total": entry["Tests Completed"]});
    }
  }

  // add aggregated results to target collection
  let operations = [];
  weeklyResults.forEach((tests, week) => {
    operations.push({
      "replaceOne": {
        "filter": {
          "school": "Northeastern",
          "week": week,
        },
        "replacement": {
          "school": "Northeastern",
          "week": week,
          "positive": tests.positive,
          "total": tests.total,
        },
        "upsert": true
      }
    })
  });

  return await targetCollection.bulkWrite(operations);
};
