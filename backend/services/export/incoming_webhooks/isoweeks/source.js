exports = async function(payload, response) {
  // aggregate data from different collections by ISO week for downstream analyses
  const database = context.services.get("mongodb-atlas").db("covid");
  const collection = database.collection("isoweeks");

  const results = await collection.find().toArray();
  response.setStatusCode(200);

  if (payload.query.format === "csv") {
    let csv = [
      "school,week,county_positive,county_density,county_vaccine,state_positive,state_density,state_vaccine,metro_positive,metro_density,metro_vaccine,positive,total"
    ];
    for (const entry of results) {
      const row = [
        entry.school, entry.week,
        entry.county.positives, entry.county.density, entry.county.vaccinations,
        entry.state.positives, entry.state.density, entry.state.vaccinations,
        entry.metro.positives, entry.metro.density, entry.metro.vaccinations,
        entry.positives, entry.tests
      ];
      csv.push(row.join(","));
    }
    response.setHeader("Content-Type", "text/csv; charset=UTF-8");
    response.addHeader("Content-Disposition", 'attachment; filename="isoweeks.csv"');
    response.setBody(csv.join("\n"));
  } else {
    response.setHeader("Content-Type", "application/json; charset=UTF-8");
    response.setBody(JSON.stringify(results));
  }
};
