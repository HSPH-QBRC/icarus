exports = async function(payload, response) {
  // provide data for analysis report Shiny app
  const database = context.services.get("mongodb-atlas").db("covid");
  const collection = database.collection("report");

  const results = await collection.find().toArray();
  response.setStatusCode(200);

  let csv = [
    ",school,week,county_positive,county_density,state_positive,state_density,metro_positive,metro_density,positive,total"
  ];
  for (const entry of results) {
    const row = [
      entry[""], entry.school, entry.week,
      entry.county_positive, entry.county_density,
      entry.state_positive, entry.state_density,
      entry.metro_positive, entry.metro_density,
      entry.positive, entry.total
    ];
    csv.push(row.join(","));
  }
  response.setHeader("Content-Type", "text/csv; charset=UTF-8");
  response.addHeader("Content-Disposition", 'attachment; filename="report.csv"');
  response.setBody(csv.join("\n"));
};
