exports = async function() {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("counties");
  // prepare API request
  const today = new Date();
  const endDate = context.functions.execute("toDelphiDate", today);
  const startDate = context.functions.execute("toDelphiDate", new Date(today - 30 * 60 * 60 * 24 * 1000)); // last 30 days
  const counties = context.values.get("counties");
  const params = {
    "data_source": "jhu-csse",
    "signal": "confirmed_incidence_num,confirmed_incidence_prop",
    "geo_type": "county",
    "geo_values": Object.keys(counties).join(","),
    "time_type": "day",
    "time_values": `${startDate}-${endDate}`,
  }

  let response;
  try {
    response = await context.functions.execute("getDelphiApiData", params);
  } catch (err) {
    console.error(err);
    return;
  }
  // update collection
  const updates = response["epidata"].map(record => {
    return {
      "replaceOne": {
        "filter": {
          "date": context.functions.execute("fromDelphiDate", record["time_value"]),
          "county_fips": record["geo_value"],
          "signal": record["signal"],
        },
        "replacement": {
          "date": context.functions.execute("fromDelphiDate", record["time_value"]),
          "signal": record["signal"],
          "county_fips": record["geo_value"],
          "county_name": counties[record["geo_value"]],
          "cases": record["value"],
        },
        "upsert": true
      }
    };
  });

  await collection.bulkWrite(updates);
  console.log(`Updated ${updates.length} records`);
  return response["message"];
};
