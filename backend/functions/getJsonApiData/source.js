exports = async function(request){
  const response = await context.http.get(request);
  if (response.statusCode != 200) {
    throw new Error(`API response status: ${response.status}`);
  }
  let payload;
  try {
    payload = response.body.text();
  } catch (err) {
    throw new Error(`Empty payload in API response`);
  }
  try {
    // The response body is a BSON.Binary object. Parse it and return.
    return EJSON.parse(payload);
  } catch (err) {
    throw new Error(`Failed to parse API response body: ${err}\nResponse body: ${payload}`);
  }
};
