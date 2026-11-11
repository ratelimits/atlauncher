.pragma library
/* Normalize the TV's locale values without changing its system settings. */
function region(value) {
    var text = String(value || '').toUpperCase();
    // ISO 3-letter codes (some TVs report the country that way) for the Streaming Region choices.
    var legacy = { ARE: 'AE', ARG: 'AR', AUS: 'AU', AUT: 'AT', BEL: 'BE', BRA: 'BR', CAN: 'CA', CHE: 'CH', CHL: 'CL',
                   COL: 'CO', CZE: 'CZ', DEU: 'DE', DNK: 'DK', ESP: 'ES', FIN: 'FI', FRA: 'FR', GBR: 'GB', HUN: 'HU',
                   IDN: 'ID', IND: 'IN', IRL: 'IE', ITA: 'IT', JPN: 'JP', KOR: 'KR', MEX: 'MX', MYS: 'MY', NLD: 'NL',
                   NOR: 'NO', NZL: 'NZ', PHL: 'PH', POL: 'PL', PRT: 'PT', SAU: 'SA', SGP: 'SG', SWE: 'SE', THA: 'TH',
                   TUR: 'TR', USA: 'US', ZAF: 'ZA' };
    return /^[A-Z]{2}$/.test(text) ? text : (legacy[text] || 'US');
}
function language(value) {
    var text = String(value || '').replace(/_/g, '-');
    if (!/^[a-z]{2,3}(-[A-Za-z]{2})?$/.test(text)) return 'en-US';
    var parts = text.split('-');
    return parts[0] + (parts[1] ? '-' + parts[1].toUpperCase() : '');
}
function options(prefs, tvRegion, tvLanguage) {
    return { region: region(prefs.tmdbRegion === 'auto' || !prefs.tmdbRegion ? tvRegion : prefs.tmdbRegion),
             language: language(prefs.tmdbLanguage === 'auto' || !prefs.tmdbLanguage ? tvLanguage : prefs.tmdbLanguage) };
}
function context(options) { return options.region + '|' + options.language + '|3'; }
function clockMode(prefs) {
    if (prefs.clockMode === '12' || prefs.clockMode === '24') return prefs.clockMode;
    if (prefs.clockMode === 'auto') return 'auto';
    // Preserve a previously saved manual choice from the first clock settings release.
    return typeof prefs.clock12h === 'boolean' ? (prefs.clock12h ? '12' : '24') : 'auto';
}
function use12Hour(prefs, tvTimeFormat) {
    var mode = clockMode(prefs);
    return mode === '12' || (mode === 'auto' && tvTimeFormat === 'HH12');
}
function next(values, value) { return values[(values.indexOf(value) + 1) % values.length]; }
