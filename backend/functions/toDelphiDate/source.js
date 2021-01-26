exports = function toDelphiDate(dateObj) {
  // convert Date object to string in YYYYMMDD format
  return dateObj.toISOString().substring(0, 10).replace(/-/g, "");
};
