exports = function fromDelphiDate(date) {
  // convert integer date in YYYYMMDD format to Date object
  date = date.toString();
  const year = date.substring(0, 4);
  const month = date.substring(4, 6);
  const day = date.substring(6, 8);
  return new Date(year + "-" + month + "-" + day);
};
