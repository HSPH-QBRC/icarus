// This function is the webhook's request handler
exports = async function(payload, response) {
  const collection = context.services.get("mongodb-atlas").db("covid").collection("princeton");

  let tests = EJSON.parse(payload.body.text());

  const updates = tests.map(test => {
    test["week_ending"] = new Date(test["week_ending"]);
    const query = {
      "week_ending": test["week_ending"],
      "group": test["group"],
      "testing_type": test["testing_type"]
    };
    return { "replaceOne": { "filter": query, "replacement": test, "upsert": true } };
  });

  await collection.bulkWrite(updates);
  console.log(`Updated ${updates.length} testing records`);
  // The return value of the function is sent as the response back to the client
  // when the "Respond with Result" setting is set.
  return "Success!";
};
