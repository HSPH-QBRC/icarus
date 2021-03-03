exports = async function(payload, response) {
  const mmwr = require("mmwr-week");
  let mdate = new mmwr.MMWRDate();
  const collection = context.services.get("mongodb-atlas").db("covid").collection("harvard");
  const docs = await collection.find({}, {"_id": 0})
    .sort({"date": 1})
    .toArray();
  let weeklyResults = new Map();
  docs.forEach(entry => {
    mdate.fromJSDate(new Date(entry.date));
    const epiWeek = mdate.toEpiweek();
    const sumElements = (sum, currentValue) => sum + currentValue;
    const totalPositiveTests = Object.values(entry.positives).reduce(sumElements);
    if (weeklyResults.has(epiWeek)) {
      weeklyResults.get(epiWeek).positives += totalPositiveTests;
      weeklyResults.get(epiWeek).tests += entry.tests;
    } else {
      weeklyResults.set(epiWeek, {"positives": totalPositiveTests, "tests": entry.tests});
    }
  });
  let csv = ["epiweek,positives,tests"];
  for (const [epiWeek, data] of weeklyResults) {
    csv.push(`${epiWeek},${data.positives},${data.tests}`);
  }
  response.setStatusCode(200);
  response.setHeader("Content-Type", "text/csv");
  response.addHeader("Content-Disposition", 'attachment; filename="harvard-epiweeks.csv"');
  response.setBody(csv.join("\n"));
};
