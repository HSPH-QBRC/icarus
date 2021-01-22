exports = async function() {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("counties");
  // prepare API request
  const signals = "confirmed_incidence_num,confirmed_incidence_prop";
  const today = new Date();
  const endDate = toDelphiDate(today);
  const startDate = toDelphiDate(new Date(today - 30 * 60 * 60 * 24 * 1000)); // last 30 days
  const counties = context.values.get("counties");
  const countyCodes = Object.keys(counties).join(",");
  const params = `&data_source=jhu-csse&signal=${signals}&time_type=day&time_values=${startDate}-${endDate}&geo_type=county&geo_values=${countyCodes}`;
  const request = { url: context.values.get("delphiEpidataApiBaseUrl") + params };

  let response;
  try {
    response = await context.functions.execute("getJsonApiData", request);
  } catch (err) {
    console.error(err);
    return;
  }
  switch (response["result"]) {
    case 1: // success
      break;
    case -1:
      console.error(`API error: ${response["message"]}`);
      return;
    case 2:
      console.error("The number of results you requested was greater than the API’s maximum results limit");
      return;
    case -2:
      console.error("No results returned from the API");
      return;
    default:
      console.error(`Unknown result code returned from the API: ${response["result"]}`);
      return;
  }
  // update collection
  const updates = response["epidata"].map(record => {
    return {
      "replaceOne": {
        "filter": {
          "date": fromDelphiDate(record["time_value"]),
          "county_fips": record["geo_value"],
          "signal": record["signal"],
        },
        "replacement": {
          "date": fromDelphiDate(record["time_value"]),
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

function toDelphiDate(dateObj) {
  // convert Date object to string in YYYYMMDD format
  return dateObj.toISOString().substring(0, 10).replace(/-/g, "");
}

function fromDelphiDate(date) {
  // convert integer date in YYYYMMDD format to Date object
  date = date.toString();
  const year = date.substring(0, 4);
  const month = date.substring(4, 6);
  const day = date.substring(6, 8);
  return new Date(year + "-" + month + "-" + day);
}
