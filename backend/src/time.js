const TIME_ZONE = process.env.APP_TIMEZONE || 'Africa/Kampala';

function localParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: TIME_ZONE,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hourCycle: 'h23'
  }).formatToParts(date);
  return Object.fromEntries(parts.map(p => [p.type, p.value]));
}

function localDateTime(date = new Date()) {
  const p = localParts(date);
  return `${p.year}-${p.month}-${p.day} ${p.hour}:${p.minute}:${p.second}`;
}

function localDate(date = new Date()) {
  return localDateTime(date).slice(0, 10);
}

function localTime(date = new Date()) {
  return localDateTime(date).slice(11, 16);
}

function weekday(dateString) {
  // Noon with the Kampala offset avoids date-boundary ambiguity.
  return new Date(`${dateString}T12:00:00+03:00`).getDay();
}

module.exports = { TIME_ZONE, localDateTime, localDate, localTime, weekday };
