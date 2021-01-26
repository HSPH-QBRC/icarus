exports = async function() {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("states");
  // prepare API request
  const today = new Date();
  const endDate = context.functions.execute("toDelphiDate", today);
  const startDate = context.functions.execute("toDelphiDate", new Date(today - 30 * 60 * 60 * 24 * 1000)); // last 30 days
  const params = {
    "data_source": "jhu-csse",
    "signal": "confirmed_incidence_num,confirmed_incidence_prop",
    "geo_type": "state",
    "geo_value": "*",
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
          "state": record["geo_value"],
          "signal": record["signal"],
        },
        "replacement": {
          "date": context.functions.execute("fromDelphiDate", record["time_value"]),
          "signal": record["signal"],
          "state": record["geo_value"],
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
