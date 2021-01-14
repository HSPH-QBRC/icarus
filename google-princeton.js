function exportToIcarus() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Sheet1');
  const headerRows = 1;  // number of rows of header info (to skip)
  const range = sheet.getDataRange(); // determine the range of populated data
  const numRows = range.getNumRows(); // get the number of rows in the range
  const values = range.getValues(); // get the actual data in an array data[row][column]

  let tests = [];
  for (let i=headerRows; i<numRows; i++) {
    let row = values[i];
    tests.push({
      'week_ending': Utilities.formatDate(new Date(row[0]), 'America/New_York', "yyyy-MM-dd'T'HH:mm:ss'Z'"),
      'group': row[1],
      'testing_type': row[2],
      'tests': row[3],
      'positive_cases': row[4]
    });
  }
  // Make a POST request with a JSON payload
  const options = {
    'method': 'post',
    'contentType': 'application/json',
    'payload': JSON.stringify(tests)
  };
  const url = 'https://webhooks.mongodb-realm.com/api/client/v2.0/app/dev-icarus-mzcsi/service/google/incoming_webhook/princeton-testing';
  var response = UrlFetchApp.fetch(url, options);
  Logger.log(response);
}
