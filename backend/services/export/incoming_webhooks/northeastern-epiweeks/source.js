exports = async function(payload, response) {
  const mmwr = require("mmwr-week");
  let mdate = new mmwr.MMWRDate();
  const collection = context.services.get("mongodb-atlas").db("covid").collection("northeastern");
  const docs = await collection.find({}, {"Date": 1, "Positive Tests": 1, "Tests Completed": 1})
    .sort({"Date": 1})
    .toArray();
  let weeklyResults = new Map();
  docs.forEach(entry => {
    mdate.fromJSDate(new Date(entry["Date"]));
    const epiWeek = mdate.toEpiweek();
    if (weeklyResults.has(epiWeek)) {
      weeklyResults.get(epiWeek).positives += entry["Positive Tests"];
      weeklyResults.get(epiWeek).tests += entry["Tests Completed"];
    } else {
      weeklyResults.set(epiWeek, {"positives": entry["Positive Tests"], "tests": entry["Tests Completed"]});
    }
  });
  let csv = ["epiweek,positives,tests"];
  for (const [epiWeek, data] of weeklyResults) {
    csv.push(`${epiWeek},${data.positives},${data.tests}`);
  }
  response.setStatusCode(200);
  response.setHeader("Content-Type", "text/csv");
  response.addHeader("Content-Disposition", 'attachment; filename="northeastern-epiweeks.csv"');
  response.setBody(csv.join("\n"));
};
