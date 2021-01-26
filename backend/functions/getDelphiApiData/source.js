exports = async function(paramsObj) {
  const paramsArray = Object.entries(paramsObj).map(([key, value]) => {
    return `&${key}=${value}`;
  });
  const request = { url: context.values.get("delphiEpidataApiBaseUrl") + paramsArray.join("") };
  const response = await context.functions.execute("getJsonApiData", request);
  switch (response["result"]) {
    case 1: // success
      return response;
    case -1:
      throw new Error(`API error: ${response["message"]}`);
    case 2:
      throw new Error("The number of results you requested was greater than the API’s maximum results limit");
    case -2:
      throw new Error("No results returned from the API");
    default:
      throw new Error(`Unknown result code returned from the API: ${response["result"]}`);
  }
};
