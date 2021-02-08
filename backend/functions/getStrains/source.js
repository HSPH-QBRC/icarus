exports = async function(){
  const request = {
    url: "https://covid-api.bit.io/metadata?country=eq.USA&virus=eq.ncov&select=strain,division,age,sex,date,gisaid_epi_isl",
    headers: { "Accept-Profile": ["nextstrain"] }
  };
  const response = await context.functions.execute("getJsonApiData", request);
  const collection = context.services.get("mongodb-atlas").db("covid").collection("strains");

  await collection.bulkWrite(response.map(record => {
    return {
      "replaceOne": {
        "filter": {
          "date": new Date(record["date"]),
          "strain": record["strain"],
          "division": record["division"],
          "gisaid_epi_isl": record["gisaid_epi_isl"],
          "age": record["age"],
          "sex": record["sex"],
        },
        "replacement": {
          "date": new Date(record["date"]),
          "strain": record["strain"],
          "division": record["division"],
          "gisaid_epi_isl": record["gisaid_epi_isl"],
          "age": record["age"],
          "sex": record["sex"],
        },
        "upsert": true
      }
    };
  }));
  console.log(`Updated ${response.length} records`);
};
