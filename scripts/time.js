function TER (c) {
  this.container = c;
  this._initialize ();
} // TER

(function () {

  /* Based on HTML Standard's definition of "global date and time
     string", but allows Unicode 5.1.0 White_Space where it was
     allowed in earlier drafts of HTML5. */
  var globalDateAndTimeStringPattern = /^([0-9]{4,})-([0-9]{2})-([0-9]{2})(?:[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+(?:T[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*)?|T[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*)([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.([0-9]+))?)?[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*(?:Z|([+-])([0-9]{2}):([0-9]{2}))$/;

  /* HTML Standard's definition of "date string" */
  var dateStringPattern = /^([0-9]{4,})-([0-9]{2})-([0-9]{2})$/;

  function parseTimeElement (el) {
    var datetime = el.getAttribute ('datetime');
    if (datetime === null) {
      datetime = el.textContent;

      /* Unicode 5.1.0 White_Space */
      datetime = datetime.replace
                     (/^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/, '')
                         .replace
                     (/[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+$/, '');
    }

    if (m = datetime.match (globalDateAndTimeStringPattern)) {
      if (m[1] < 100) {
        return new Date (NaN);
      } else if (m[8] && (m[9] > 23 || m[9] < -23)) {
        return new Date (NaN);
      } else if (m[8] && m[10] > 59) {
        return new Date (NaN);
      }
      var d = new Date (Date.UTC (m[1], m[2] - 1, m[3], m[4], m[5], m[6] || 0));
      if (m[1] != d.getUTCFullYear () ||
          m[2] != d.getUTCMonth () + 1 ||
          m[3] != d.getUTCDate () ||
          m[4] != d.getUTCHours () ||
          m[5] != d.getUTCMinutes () ||
          (m[6] || 0) != d.getUTCSeconds ()) {
        return new Date (NaN); // bad date error.
      }
      if (m[7]) {
        var ms = (m[7] + "000").substring (0, 3);
        d.setMilliseconds (ms);
      }
      if (m[9] != null) {
        var offset = parseInt (m[9], 10) * 60 + parseInt (m[10], 10);
        offset *= 60 * 1000;
        if (m[8] == '-') offset *= -1;
        d = new Date (d.valueOf () - offset);
      }
      d.hasDate = true;
      d.hasTime = true;
      d.hasTimezone = true;
      return d;
    } else if (m = datetime.match (dateStringPattern)) {
      if (m[1] < 100) {
        return new Date (NaN);
      }
      /* For old browsers (which don't support the options parameter
         of `toLocaleDateString` method) the time value is set to
         12:00, so that most cases are covered. */
      var d = new Date (Date.UTC (m[1], m[2] - 1, m[3], 12, 0, 0));
      if (m[1] != d.getUTCFullYear () ||
          m[2] != d.getUTCMonth () + 1 ||
          m[3] != d.getUTCDate ()) {
        return new Date (NaN); // bad date error.
      }
      d.hasDate = true;
      return d;
    } else {
      return new Date (NaN);
    }
  } // parseTimeElement

  function setDateContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      var r = '';
      r = date.getUTCFullYear (); // JS does not support years 0001-0999
      r += '-' + ('0' + (date.getUTCMonth () + 1)).slice (-2);
      r += '-' + ('0' + date.getUTCDate ()).slice (-2);
      el.setAttribute ('datetime', r);
    }
    el.textContent = date.toLocaleDateString (navigator.language, {"timeZone": "UTC"});
  } // setDateContent

  function setMonthDayDateContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      var r = '';
      r = date.getUTCFullYear (); // JS does not support years 0001-0999
      r += '-' + ('0' + (date.getUTCMonth () + 1)).slice (-2);
      r += '-' + ('0' + date.getUTCDate ()).slice (-2);
      el.setAttribute ('datetime', r);
    }

    var lang = navigator.language;
    if (new Date ().toLocaleString (lang, {timeZone: 'UTC', year: "numeric"}) ===
        date.toLocaleString (lang, {timeZone: 'UTC', year: "numeric"})) {
      el.textContent = date.toLocaleDateString (lang, {
        "timeZone": "UTC",
        month: "numeric",
        day: "numeric",
      });
    } else {
      el.textContent = date.toLocaleDateString (lang, {
        "timeZone": "UTC",
      });
    }
  } // setDateContent

  function setDateTimeContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      // XXX If year is outside of 1000-9999, ...
      el.setAttribute ('datetime', date.toISOString ());
    }

    var tzoffset = el.getAttribute ('data-tzoffset');
    if (tzoffset !== null) {
      tzoffset = parseFloat (tzoffset);
      el.textContent = new Date (date.valueOf () + date.getTimezoneOffset () * 60 * 1000 + tzoffset * 1000).toLocaleString (navigator.language, {
        year: "numeric",
        month: "numeric",
        day: "numeric",
        hour: "numeric",
        minute: "numeric",
        second: "numeric",
      });
    } else {
      el.textContent = date.toLocaleString ();
    }
  } // setDateTimeContent

  function setAmbtimeContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      // XXX If year is outside of 1000-9999, ...
      el.setAttribute ('datetime', date.toISOString ());
    }

    var text = TER.Delta.prototype.text;
    var dateValue = date.valueOf ();
    var nowValue = new Date ().valueOf ();

    var diff = dateValue - nowValue;
    if (diff < 0) diff = -diff;

    if (diff == 0) {
      el.textContent = text.now ();
      return;
    }

    var v;
    diff = Math.floor (diff / 1000);
    if (diff < 60) {
      v = text.second (diff);
    } else {
      var f = diff;
      diff = Math.floor (diff / 60);
      if (diff < 60) {
        v = text.minute (diff);
        f -= diff * 60;
        if (f > 0) v += text.sep () + text.second (f);
      } else {
        f = diff;
        diff = Math.floor (diff / 60);
        if (diff < 50) {
          v = text.hour (diff);
          f -= diff * 60;
          if (f > 0) v += text.sep () + text.minute (f);
        } else {
          f = diff;
          diff = Math.floor (diff / 24);
          if (diff < 100) {
            v = text.day (diff);
            f -= diff * 24;
            if (f > 0) v += text.sep () + text.hour (f);
          } else {
            return setDateTimeContent (el, date);
          }
        }
      }
    }

    if (dateValue < nowValue) {
      v = text.before (v);
    } else {
      v = text.after (v);
    }
    el.textContent = v;
  } // setAmbtimeContent

TER.prototype._initialize = function () {
  if (this.container.localName === 'time') {
    this._initTimeElement (this.container);
  } else {
    var els = this.container.getElementsByTagName ('time');
    var elsL = els.length;
    for (var i = 0; i < elsL; i++) {
      var el = els[i];
      if (!el) break; /* If <time> is nested */
      this._initTimeElement (el);
    }
  }
}; // TER.prototype._initialize

  TER.prototype._initTimeElement = function (el) {
    if (el.terUpgraded) return;
    el.terUpgraded = true;
    
    var self = this;
    this._replaceTimeContent (el);
    new MutationObserver (function (mutations) {
      self._replaceTimeContent (el);
    }).observe (el, {attributeFilter: ['data-tzoffset']});
  }; // _initTimeElement

  TER.prototype._replaceTimeContent = function (el) {
    var date = parseTimeElement (el);
    if (isNaN (date.valueOf ())) return;
    if (date.hasTimezone) { /* full date */
      setDateTimeContent (el, date);
    } else if (date.hasDate) {
      setDateContent (el, date);
    }
  }; // _replaceTimeContent

  TER.Delta = function (c) {
    TER.apply (this, [c]);
  }; // TER.Delta
  TER.Delta.prototype = new TER (document.createElement ('time'));

  TER.Delta.prototype._replaceTimeContent = function (el) {
    var date = parseTimeElement (el);
    if (isNaN (date.valueOf ())) return;
    if (date.hasTimezone) { /* full date */
      setAmbtimeContent (el, date);
    } else if (date.hasDate) {
      setDateContent (el, date);
    }
  }; // _replaceTimeContent

  (function (selector) {
    if (!selector) return;

    var replaceContent = function (el) {
      var date = parseTimeElement (el);
      if (isNaN (date.valueOf ())) return;
      var format = el.getAttribute ('data-format');
      if (format === 'datetime') {
        setDateTimeContent (el, date);
      } else if (format === 'date') {
        setDateContent (el, date);
      } else if (format === 'monthday') {
        setMonthDayDateContent (el, date);
      } else if (format === 'ambtime') {
        setAmbtimeContent (el, date);
      } else { // auto
        if (date.hasTimezone) { /* full date */
          setDateTimeContent (el, date);
        } else if (date.hasDate) {
          setDateContent (el, date);
        }
      }
    }; // replaceContent
    
    var op = function (el) {
      if (el.terUpgraded) return;
      el.terUpgraded = true;

      replaceContent (el);
      new MutationObserver (function (mutations) {
        replaceContent (el);
      }).observe (el, {attributeFilter: ['datetime', 'data-tzoffset']});
    }; // op
    
    var mo = new MutationObserver (function (mutations) {
      mutations.forEach (function (m) {
        Array.prototype.forEach.call (m.addedNodes, function (e) {
          if (e.nodeType === e.ELEMENT_NODE) {
            if (e.matches && e.matches (selector)) op (e);
            Array.prototype.forEach.call (e.querySelectorAll (selector), op);
          }
        });
      });
    });
    mo.observe (document, {childList: true, subtree: true});
    Array.prototype.forEach.call (document.querySelectorAll (selector), op);

  }) (document.currentScript.getAttribute ('data-time-selector') ||
      document.currentScript.getAttribute ('data-selector') /* backcompat */);
}) ();

TER.Delta.Text = {};

TER.Delta.Text.en = {
  day: function (n) {
    return n + ' day' + (n == 1 ? '' : 's');
  },
  hour: function (n) {
    return n + ' hour' + (n == 1 ? '' : 's');
  },
  minute: function (n) {
    return n + ' minute' + (n == 1 ? '' : 's');
  },
  second: function (n) {
    return n + ' second' + (n == 1 ? '' : 's');
  },
  before: function (s) {
    return s + ' ago';
  },
  after: function (s) {
    return 'in ' + s;
  },
  now: function () {
    return 'just now';
  },
  sep: function () {
    return ' ';
  }
};

TER.Delta.Text.ja = {
  day: function (n) {
    return n + '日';
  },
  hour: function (n) {
    return n + '時間';
  },
  minute: function (n) {
    return n + '分';
  },
  second: function (n) {
    return n + '秒';
  },
  before: function (s) {
    return s + '前';
  },
  after: function (s) {
    return s + '後';
  },
  now: function () {
    return '今';
  },
  sep: function () {
    return '';
  }
};

(function () {
  var lang = navigator.language;
  if (lang.match (/^[jJ][aA](?:-|$)/)) {
    TER.Delta.prototype.text = TER.Delta.Text.ja;
  } else {
    TER.Delta.prototype.text = TER.Delta.Text.en;
  }
})();

if (window.TEROnLoad) {
  TEROnLoad ();
}

/*

Usage:

Just insert:

  <script src="path/to/time.js" data-time-selector="time" async></script>

... where the |data-time-selector| attribute value is a selector that
only matches with |time| elements that should be processed.  Then any
|time| element matched with the selector when the script is executed,
as well as any |time| element matched with the selector inserted after
the script's execution, is processed appropriately.  E.g.:

  <time>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date and time in the user's locale
       dependent format, such as "20 December 2008 11:27 PM" -->

  <time>2008-12-20</time>
  <time data-format=date>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date in the user's locale dependent
       format, such as "20 December 2008" -->

  <time>2008-12-20</time>
  <time data-format=date>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date in the user's locale dependent
       format, such as "20 December 2008" but the year component is
       omitted if it is same as this year, such as "December 20" in
       case it's 2008. -->

  <time data-format=ambtime>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as an "ambtime" in English or Japanese
       depending on the user's language preference, such as "2 hours
       ago" -->

When the |time| element's |datetime| or |data-tzoffset| attribute
value is changed, the element's content is updated appropriately.
(Note that the element's content's mutation is ignored.)

For backward compatibility with previous versions of this script, if
there is no |data-time-selector| or |data-selector| attribute, the
script does nothing by default, except for defining the |TER| global
property.  By invoking |new TER (/element/)| or |new TER.Delta
(/element/)| constructor, where /element/ is an element node, any
|time| element in the /element/ subtree (or /element/ itself if it is
a |time| element) is processed appropriately.  The |TER| constructor
is equivalent to no |data-format| attribute and the |TER.Delta|
constructor is equivalent to |data-format=ambtime|.

Repository:

Latest version of this script is available in Git repository
<https://github.com/wakaba/timejs>.

Specification:

HTML Standard <https://html.spec.whatwg.org/#the-time-element>.

This script interprets "global date and time string" using older
parsing rules as defined in previous versions of the HTML spec, which
is a willful violation to the current HTML Living Standard.

*/

/* ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright 2008-2019 Wakaba <wakaba@suikawiki.org>.  All rights reserved.
 *
 * Copyright 2017 Hatena <http://hatenacorp.jp/>.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or 
 * modify it under the same terms as Perl itself.
 *
 * Alternatively, the contents of this file may be used 
 * under the following terms (the "MPL/GPL/LGPL"), 
 * in which case the provisions of the MPL/GPL/LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of the MPL/GPL/LGPL, and not to allow others to
 * use your version of this file under the terms of the Perl, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the MPL/GPL/LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the Perl or the MPL/GPL/LGPL.
 *
 * "MPL/GPL/LGPL":
 *
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * <https://www.mozilla.org/MPL/>
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is TER code.
 *
 * The Initial Developer of the Original Code is Wakaba.
 * Portions created by the Initial Developer are Copyright (C) 2008
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Wakaba <wakaba@suikawiki.org>
 *   Hatena <http://hatenacorp.jp/>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the LGPL or the GPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */
/*
 (c) 2011-2015, Vladimir Agafonkin
 SunCalc is a JavaScript library for calculating sun/moon position and light phases.
 https://github.com/mourner/suncalc
*/

(function () { 'use strict';

// shortcuts for easier to read formulas

var PI   = Math.PI,
    sin  = Math.sin,
    cos  = Math.cos,
    tan  = Math.tan,
    asin = Math.asin,
    atan = Math.atan2,
    acos = Math.acos,
    rad  = PI / 180;

// sun calculations are based on http://aa.quae.nl/en/reken/zonpositie.html formulas


// date/time constants and conversions

var dayMs = 1000 * 60 * 60 * 24,
    J1970 = 2440588,
    J2000 = 2451545;

function toJulian(date) { return date.valueOf() / dayMs - 0.5 + J1970; }
function fromJulian(j)  { return new Date((j + 0.5 - J1970) * dayMs); }
function toDays(date)   { return toJulian(date) - J2000; }


// general calculations for position

var e = rad * 23.4397; // obliquity of the Earth

function rightAscension(l, b) { return atan(sin(l) * cos(e) - tan(b) * sin(e), cos(l)); }
function declination(l, b)    { return asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l)); }

function azimuth(H, phi, dec)  { return atan(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi)); }
function altitude(H, phi, dec) { return asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H)); }

function siderealTime(d, lw) { return rad * (280.16 + 360.9856235 * d) - lw; }

function astroRefraction(h) {
    if (h < 0) // the following formula works for positive altitudes only.
        h = 0; // if h = -0.08901179 a div/0 would occur.

    // formula 16.4 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
    // 1.02 / tan(h + 10.26 / (h + 5.10)) h in degrees, result in arc minutes -> converted to rad:
    return 0.0002967 / Math.tan(h + 0.00312536 / (h + 0.08901179));
}

// general sun calculations

function solarMeanAnomaly(d) { return rad * (357.5291 + 0.98560028 * d); }

function eclipticLongitude(M) {

    var C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M)), // equation of center
        P = rad * 102.9372; // perihelion of the Earth

    return M + C + P + PI;
}

function sunCoords(d) {

    var M = solarMeanAnomaly(d),
        L = eclipticLongitude(M);

    return {
        dec: declination(L, 0),
        ra: rightAscension(L, 0)
    };
}


var SunCalc = {};


// calculates sun position for a given date and latitude/longitude

SunCalc.getPosition = function (date, lat, lng) {

    var lw  = rad * -lng,
        phi = rad * lat,
        d   = toDays(date),

        c  = sunCoords(d),
        H  = siderealTime(d, lw) - c.ra;

    return {
        azimuth: azimuth(H, phi, c.dec),
        altitude: altitude(H, phi, c.dec)
    };
};


// sun times configuration (angle, morning name, evening name)

var times = SunCalc.times = [
    [-0.833, 'sunrise',       'sunset'      ],
    [  -0.3, 'sunriseEnd',    'sunsetStart' ],
    [    -6, 'dawn',          'dusk'        ],
    [   -12, 'nauticalDawn',  'nauticalDusk'],
    [   -18, 'nightEnd',      'night'       ],
    [     6, 'goldenHourEnd', 'goldenHour'  ]
];

// adds a custom time to the times config

SunCalc.addTime = function (angle, riseName, setName) {
    times.push([angle, riseName, setName]);
};


// calculations for sun times

var J0 = 0.0009;

function julianCycle(d, lw) { return Math.round(d - J0 - lw / (2 * PI)); }

function approxTransit(Ht, lw, n) { return J0 + (Ht + lw) / (2 * PI) + n; }
function solarTransitJ(ds, M, L)  { return J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L); }

function hourAngle(h, phi, d) { return acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d))); }

// returns set time for the given sun altitude
function getSetJ(h, lw, phi, dec, n, M, L) {

    var w = hourAngle(h, phi, dec),
        a = approxTransit(w, lw, n);
    return solarTransitJ(a, M, L);
}


// calculates sun times for a given date and latitude/longitude

SunCalc.getTimes = function (date, lat, lng) {

    var lw = rad * -lng,
        phi = rad * lat,

        d = toDays(date),
        n = julianCycle(d, lw),
        ds = approxTransit(0, lw, n),

        M = solarMeanAnomaly(ds),
        L = eclipticLongitude(M),
        dec = declination(L, 0),

        Jnoon = solarTransitJ(ds, M, L),

        i, len, time, Jset, Jrise;


    var result = {
        solarNoon: fromJulian(Jnoon),
        nadir: fromJulian(Jnoon - 0.5)
    };

    for (i = 0, len = times.length; i < len; i += 1) {
        time = times[i];

        Jset = getSetJ(time[0] * rad, lw, phi, dec, n, M, L);
        Jrise = Jnoon - (Jset - Jnoon);

        result[time[1]] = fromJulian(Jrise);
        result[time[2]] = fromJulian(Jset);
    }

    return result;
};


// moon calculations, based on http://aa.quae.nl/en/reken/hemelpositie.html formulas

function moonCoords(d) { // geocentric ecliptic coordinates of the moon

    var L = rad * (218.316 + 13.176396 * d), // ecliptic longitude
        M = rad * (134.963 + 13.064993 * d), // mean anomaly
        F = rad * (93.272 + 13.229350 * d),  // mean distance

        l  = L + rad * 6.289 * sin(M), // longitude
        b  = rad * 5.128 * sin(F),     // latitude
        dt = 385001 - 20905 * cos(M);  // distance to the moon in km

    return {
        ra: rightAscension(l, b),
        dec: declination(l, b),
        dist: dt
    };
}

SunCalc.getMoonPosition = function (date, lat, lng) {

    var lw  = rad * -lng,
        phi = rad * lat,
        d   = toDays(date),

        c = moonCoords(d),
        H = siderealTime(d, lw) - c.ra,
        h = altitude(H, phi, c.dec),
        // formula 14.1 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.
        pa = atan(sin(H), tan(phi) * cos(c.dec) - sin(c.dec) * cos(H));

    h = h + astroRefraction(h); // altitude correction for refraction

    return {
        azimuth: azimuth(H, phi, c.dec),
        altitude: h,
        distance: c.dist,
        parallacticAngle: pa
    };
};


// calculations for illumination parameters of the moon,
// based on http://idlastro.gsfc.nasa.gov/ftp/pro/astro/mphase.pro formulas and
// Chapter 48 of "Astronomical Algorithms" 2nd edition by Jean Meeus (Willmann-Bell, Richmond) 1998.

SunCalc.getMoonIllumination = function (date) {

    var d = toDays(date || new Date()),
        s = sunCoords(d),
        m = moonCoords(d),

        sdist = 149598000, // distance from Earth to Sun in km

        phi = acos(sin(s.dec) * sin(m.dec) + cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra)),
        inc = atan(sdist * sin(phi), m.dist - sdist * cos(phi)),
        angle = atan(cos(s.dec) * sin(s.ra - m.ra), sin(s.dec) * cos(m.dec) -
                cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra));

    return {
        fraction: (1 + cos(inc)) / 2,
        phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / Math.PI,
        angle: angle
    };
};


function hoursLater(date, h) {
    return new Date(date.valueOf() + h * dayMs / 24);
}

// calculations for moon rise/set times are based on http://www.stargazing.net/kepler/moonrise.html article

SunCalc.getMoonTimes = function (date, lat, lng, inUTC) {
    var t = new Date(date);
    if (inUTC) t.setUTCHours(0, 0, 0, 0);
    else t.setHours(0, 0, 0, 0);

    var hc = 0.133 * rad,
        h0 = SunCalc.getMoonPosition(t, lat, lng).altitude - hc,
        h1, h2, rise, set, a, b, xe, ye, d, roots, x1, x2, dx;

    // go in 2-hour chunks, each time seeing if a 3-point quadratic curve crosses zero (which means rise or set)
    for (var i = 1; i <= 24; i += 2) {
        h1 = SunCalc.getMoonPosition(hoursLater(t, i), lat, lng).altitude - hc;
        h2 = SunCalc.getMoonPosition(hoursLater(t, i + 1), lat, lng).altitude - hc;

        a = (h0 + h2) / 2 - h1;
        b = (h2 - h0) / 2;
        xe = -b / (2 * a);
        ye = (a * xe + b) * xe + h1;
        d = b * b - 4 * a * h1;
        roots = 0;

        if (d >= 0) {
            dx = Math.sqrt(d) / (Math.abs(a) * 2);
            x1 = xe - dx;
            x2 = xe + dx;
            if (Math.abs(x1) <= 1) roots++;
            if (Math.abs(x2) <= 1) roots++;
            if (x1 < -1) x1 = x2;
        }

        if (roots === 1) {
            if (h0 < 0) rise = i + x1;
            else set = i + x1;

        } else if (roots === 2) {
            rise = i + (ye < 0 ? x2 : x1);
            set = i + (ye < 0 ? x1 : x2);
        }

        if (rise && set) break;

        h0 = h2;
    }

    var result = {};

    if (rise) result.rise = hoursLater(t, rise);
    if (set) result.set = hoursLater(t, set);

    if (!rise && !set) result[ye > 0 ? 'alwaysUp' : 'alwaysDown'] = true;

    return result;
};


// export as Node module / AMD module / browser variable
if (typeof exports === 'object' && typeof module !== 'undefined') module.exports = SunCalc;
else if (typeof define === 'function' && define.amd) define(SunCalc);
else window.SunCalc = SunCalc;

}());
/*
Copyright (c) 2014, Vladimir Agafonkin
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are
permitted provided that the following conditions are met:

   1. Redistributions of source code must retain the above copyright notice, this list of
      conditions and the following disclaimer.

   2. Redistributions in binary form must reproduce the above copyright notice, this list
      of conditions and the following disclaimer in the documentation and/or other materials
      provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
