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
  <time data-format=datetime>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date and time, e.g.
       "20 December 2008 11:27:00 PM" -->

  <time>2008-12-20</time>
  <time data-format=date>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date, e.g. "20 December 2008" -->

  <time data-format=monthday>2008-12-20</time>
  <time data-format=monthday>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date, e.g. "20 December 2008" but the
       year component is omitted if it is same as this year, e.g.
       "December 20" if it's 2008. -->

  <time data-format=monthdaytime>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a date and time, e.g.
       "20 December 2008 11:27:00 PM" but the year component is omitted
       if it is same as this year, e.g. "December 20 11:27:00 PM" if
       it's 2008. -->

  <time data-format=ambtime>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as an "ambtime" in English or Japanese
       depending on the user's language preference, such as "2 hours
       ago", if the date is within 100 days from "today" -->

  <time data-format=deltatime>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as an "ambtime" in English or Japanese
       depending on the user's language preference, such as "2 hours
       ago" -->

  <time data-format=time>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered as a time, e.g. "11:27:00 PM" -->

When the |time| element's |datetime| or |data-tzoffset| attribute
value is changed, the element's content is updated appropriately.
(Note that the element's content's mutation is ignored.)

The '--timejs-serialization' CSS property can be used to specify the
date and time serialization format.  This version supports following
serializations:

  Property value     Output example
  -----------------  ----------------------------------
  'auto' (default)   (platform dependent)
  'dtsjp1'           令和元(2019)年9月28日 1時23分45秒
  'dtsjp2'           R1(2019).9.28 1:23:45
  'dtsjp3'           2019(R1)/9/28 1:23:45

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

  function _2digit (i) {
    return i < 10 ? '0' + i : i;
  } // _2digit

  function _mod (m, n) {
    return ((m % n) + n) % n;
  };
  
  function _year (munix, year, dts) {
    var defs = TER.defs.dts[dts];
    var v = munix / 1000 / 60 / 60 / 24;
    var def = defs[0];
    for (var i = defs.length-1; i >= 1; i--) {
      if (defs[i][0] <= v) {
        def = defs[i];
        break;
      }
    }
    return def[1].map (_ => {
      if (_ instanceof Array) {
        if (_[0] === 'Y') {
          var y = year - _[1];
          return y === 1 ? '元' : y;
        } else if (_[0] === 'y') {
          return year - _[1];
        } else if (_[0] === 'k') {
          var kk = [
            '甲子','乙丑','丙寅','丁卯','戊辰','己巳','庚午','辛未','壬申',
            '癸酉','甲戌','乙亥','丙子','丁丑','戊寅','己卯','庚辰','辛巳',
            '壬午','癸未','甲申','乙酉','丙戌','丁亥','戊子','己丑','庚寅',
            '辛卯','壬辰','癸巳','甲午','乙未','丙申','丁酉','戊戌','己亥',
            '庚子','辛丑','壬寅','癸卯','甲辰','乙巳','丙午','丁未','戊申',
            '己酉','庚戌','辛亥','壬子','癸丑','甲寅','乙卯','丙辰','丁巳',
            '戊午','己未','庚申','辛酉','壬戌','癸亥',
          ];
          return kk[_mod (year - 4, 60)];
        } else {
          throw _[0];
        }
      } else {
        return _;
      }
    }).join ("");
  } // _year

  function _setDateContent (el, date) {
    var dts = getComputedStyle (el).getPropertyValue ('--timejs-serialization');
    dts = dts.replace (/^\s+/, '').replace (/\s+$/, '');
    if (dts === 'dtsjp1') {
      el.textContent = _year (date.valueOf (), date.getUTCFullYear (), dts) + '年' + (date.getUTCMonth () + 1) + '月' + date.getUTCDate () + '日(' + ['日','月','火','水','木','金','土'][date.getUTCDay ()] + ')';
    } else if (dts === 'dtsjp2') {
      el.textContent = _year (date.valueOf (), date.getUTCFullYear (), dts) + '.' + (date.getUTCMonth () + 1) + '.' + date.getUTCDate ();
    } else if (dts === 'dtsjp3') {
      el.textContent = _year (date.valueOf (), date.getUTCFullYear (), dts) + '/' + (date.getUTCMonth () + 1) + '/' + date.getUTCDate ();
    } else {
      el.textContent = date.toLocaleDateString (navigator.language, {
        "timeZone": "UTC",
      });
    }
  } // _setDateContent

  function _setMonthDayDateContent (el, date) {
    var dts = getComputedStyle (el).getPropertyValue ('--timejs-serialization');
    dts = dts.replace (/^\s+/, '').replace (/\s+$/, '');
    if (dts === 'dtsjp1') {
      el.textContent = (date.getUTCMonth () + 1) + '月' + date.getUTCDate () + '日(' + ['日','月','火','水','木','金','土'][date.getUTCDay ()] + ')';
    } else if (dts === 'dtsjp2') {
      el.textContent = (date.getUTCMonth () + 1) + '.' + date.getUTCDate ();
    } else if (dts === 'dtsjp3') {
      el.textContent = (date.getUTCMonth () + 1) + '/' + date.getUTCDate ();
    } else {
      el.textContent = date.toLocaleDateString (navigator.language, {
        "timeZone": "UTC",
        month: "numeric",
        day: "numeric",
      });
    }
  } // _setMonthDayDateContent

  function _setMonthDayTimeContent (el, date) {
    var dts = getComputedStyle (el).getPropertyValue ('--timejs-serialization');
    dts = dts.replace (/^\s+/, '').replace (/\s+$/, '');
    if (dts === 'dtsjp1') {
      el.textContent = (date.getMonth () + 1) + '月' + date.getDate () + '日(' + ['日','月','火','水','木','金','土'][date.getDay ()] + ') ' + date.getHours () + '時' + date.getMinutes () + '分' + date.getSeconds () + '秒';
    } else if (dts === 'dtsjp2') {
      el.textContent = (date.getMonth () + 1) + '.' + date.getDate () + ' ' + date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else if (dts === 'dtsjp3') {
      el.textContent = (date.getMonth () + 1) + '/' + date.getDate () + ' ' + date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else {
      el.textContent = date.toLocaleString (navigator.language, {
        month: "numeric",
        day: "numeric",
        hour: "numeric",
        minute: "numeric",
        second: "numeric",
      });
    }
  } // _setMonthDayTimeContent

  function setTimeContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      // XXX If year is outside of 1000-9999, ...
      el.setAttribute ('datetime', date.toISOString ());
    }

    var tzoffset = el.getAttribute ('data-tzoffset');
    var usedDate = date;
    if (tzoffset !== null) {
      tzoffset = parseFloat (tzoffset);
      usedDate = new Date (date.valueOf () + date.getTimezoneOffset () * 60 * 1000 + tzoffset * 1000);
    }

    _setTimeContent (el, usedDate);
  } // setTimeContent

  function _setTimeContent (el, date) {
    var dts = getComputedStyle (el).getPropertyValue ('--timejs-serialization');
    dts = dts.replace (/^\s+/, '').replace (/\s+$/, '');
    if (dts === 'dtsjp1') {
      el.textContent = date.getHours () + '時' + date.getMinutes () + '分' + date.getSeconds () + '秒';
    } else if (dts === 'dtsjp2') {
      el.textContent = date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else if (dts === 'dtsjp3') {
      el.textContent = date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else {
      el.textContent = date.toLocaleString (navigator.language, {
        hour: "numeric",
        minute: "numeric",
        second: "numeric",
      });
    }
  } // _setTimeContent

  function _setDateTimeContent (el, date) {
    var dts = getComputedStyle (el).getPropertyValue ('--timejs-serialization');
    dts = dts.replace (/^\s+/, '').replace (/\s+$/, '');
    if (dts === 'dtsjp1') {
      el.textContent = _year (date.valueOf () - date.getTimezoneOffset () * 60 * 1000, date.getFullYear (), dts) + '年' + (date.getMonth () + 1) + '月' + date.getDate () + '日(' + ['日','月','火','水','木','金','土'][date.getDay ()] + ') ' + date.getHours () + '時' + date.getMinutes () + '分' + date.getSeconds () + '秒';
    } else if (dts === 'dtsjp2') {
      el.textContent = _year (date.valueOf () - date.getTimezoneOffset () * 60 * 1000, date.getFullYear (), dts) + '.' + (date.getMonth () + 1) + '.' + date.getDate () + ' ' + date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else if (dts === 'dtsjp3') {
      el.textContent = _year (date.valueOf () - date.getTimezoneOffset () * 60 * 1000, date.getFullYear (), dts) + '/' + (date.getMonth () + 1) + '/' + date.getDate () + ' ' + date.getHours () + ':' + _2digit (date.getMinutes ()) + ':' + _2digit (date.getSeconds ());
    } else {
      el.textContent = date.toLocaleString (navigator.language, {
        year: "numeric",
        month: "numeric",
        day: "numeric",
        hour: "numeric",
        minute: "numeric",
        second: "numeric",
      });
    }
  } // _setDateTimeContent
  
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
    _setDateContent (el, date);
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
      _setMonthDayDateContent (el, date);
    } else {
      _setDateContent (el, date);
    }
  } // setMonthDayDateContent

  function setMonthDayTimeContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      // XXX If year is outside of 1000-9999, ...
      el.setAttribute ('datetime', date.toISOString ());
    }

    var tzoffset = el.getAttribute ('data-tzoffset');
    var usedDate = date;
    if (tzoffset !== null) {
      tzoffset = parseFloat (tzoffset);
      usedDate = new Date (date.valueOf () + date.getTimezoneOffset () * 60 * 1000 + tzoffset * 1000);
    }
    
    var lang = navigator.language;
    if (new Date ().toLocaleString (lang, {timeZone: 'UTC', year: "numeric"}) ===
        usedDate.toLocaleString (lang, {timeZone: 'UTC', year: "numeric"})) {
      _setMonthDayTimeContent (el, usedDate);
    } else {
      _setDateTimeContent (el, usedDate);
    }
  } // setMonthDayTimeContent

  function setDateTimeContent (el, date) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent);
    }
    if (!el.getAttribute ('datetime')) {
      // XXX If year is outside of 1000-9999, ...
      el.setAttribute ('datetime', date.toISOString ());
    }

    var tzoffset = el.getAttribute ('data-tzoffset');
    var usedDate = date;
    if (tzoffset !== null) {
      tzoffset = parseFloat (tzoffset);
      usedDate = new Date (date.valueOf () + date.getTimezoneOffset () * 60 * 1000 + tzoffset * 1000);
    }
    _setDateTimeContent (el, usedDate);
  } // setDateTimeContent

  function setAmbtimeContent (el, date, opts) {
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
          if (diff < 100 || opts.deltaOnly) {
            v = text.day (diff);
            f -= diff * 24;
            if (f > 0) v += text.sep () + text.hour (f);
          } else {
            if (opts.format === 'ambdate') {
              return setDateContent (el, date);
            } else {
              return setDateTimeContent (el, date);
            }
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
      setAmbtimeContent (el, date, {});
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
      } else if (format === 'monthdaytime') {
        setMonthDayTimeContent (el, date);
      } else if (format === 'ambtime' || format === 'ambdate') {
        setAmbtimeContent (el, date, {format});
      } else if (format === 'deltatime') {
        setAmbtimeContent (el, date, {deltaOnly: true});
      } else if (format === 'time') {
        setTimeContent (el, date);
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
    Promise.resolve ().then (() => {
      mo.observe (document, {childList: true, subtree: true});
      Array.prototype.forEach.call (document.querySelectorAll (selector), op);
    });

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


/* ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright 2008-2020 Wakaba <wakaba@suikawiki.org>.  All rights reserved.
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
TER.defs = {"dts":{"dtsjp1":[[null,["グレゴリオ暦西暦",["Y",0]]],[-962750,["グレゴリオ暦神武天皇即位前",["k"],"(",["Y",0],")"]],[-960181,["グレゴリオ暦神武天皇",["Y",-660],"(",["Y",0],")"]],[-931329,["グレゴリオ暦綏靖天皇",["Y",-581],"(",["Y",0],")"]],[-919281,["グレゴリオ暦安寧天皇",["Y",-548],"(",["Y",0],")"]],[-905401,["グレゴリオ暦懿徳天皇",["Y",-510],"(",["Y",0],")"]],[-892615,["グレゴリオ暦孝昭天皇",["Y",-475],"(",["Y",0],")"]],[-862316,["グレゴリオ暦孝安天皇",["Y",-392],"(",["Y",0],")"]],[-825049,["グレゴリオ暦孝霊天皇",["Y",-290],"(",["Y",0],")"]],[-797290,["グレゴリオ暦孝元天皇",["Y",-214],"(",["Y",0],")"]],[-776471,["グレゴリオ暦開化天皇",["Y",-157],"(",["Y",0],")"]],[-754559,["グレゴリオ暦崇神天皇",["Y",-97],"(",["Y",0],")"]],[-729724,["グレゴリオ暦垂仁天皇",["Y",-29],"(",["Y",0],")"]],[-693549,["グレゴリオ暦景行天皇",["Y",70],"(",["Y",0],")"]],[-671637,["グレゴリオ暦成務天皇",["Y",130],"(",["Y",0],")"]],[-649371,["グレゴリオ暦仲哀天皇",["Y",191],"(",["Y",0],")"]],[-646093,["グレゴリオ暦神功皇后摂政",["Y",200],"(",["Y",0],")"]],[-620874,["グレゴリオ暦応神天皇",["Y",269],"(",["Y",0],")"]],[-605164,["グレゴリオ暦仁徳天皇",["Y",312],"(",["Y",0],")"]],[-573389,["グレゴリオ暦履中天皇",["Y",399],"(",["Y",0],")"]],[-571204,["グレゴリオ暦反正天皇",["Y",405],"(",["Y",0],")"]],[-569018,["グレゴリオ暦允恭天皇",["Y",411],"(",["Y",0],")"]],[-553662,["グレゴリオ暦安康天皇",["Y",453],"(",["Y",0],")"]],[-552570,["グレゴリオ暦雄略天皇",["Y",456],"(",["Y",0],")"]],[-544183,["グレゴリオ暦清寧天皇",["Y",479],"(",["Y",0],")"]],[-542352,["グレゴリオ暦顕宗天皇",["Y",484],"(",["Y",0],")"]],[-541260,["グレゴリオ暦仁賢天皇",["Y",487],"(",["Y",0],")"]],[-537243,["グレゴリオ暦武烈天皇",["Y",498],"(",["Y",0],")"]],[-534320,["グレゴリオ暦継体天皇",["Y",506],"(",["Y",0],")"]],[-524457,["グレゴリオ暦安閑天皇",["Y",533],"(",["Y",0],")"]],[-523718,["グレゴリオ暦宣化天皇",["Y",535],"(",["Y",0],")"]],[-522271,["グレゴリオ暦欽明天皇",["Y",539],"(",["Y",0],")"]],[-510577,["グレゴリオ暦敏達天皇",["Y",571],"(",["Y",0],")"]],[-505469,["グレゴリオ暦用明天皇",["Y",585],"(",["Y",0],")"]],[-504730,["グレゴリオ暦崇峻天皇",["Y",587],"(",["Y",0],")"]],[-502899,["グレゴリオ暦推古天皇",["Y",592],"(",["Y",0],")"]],[-489758,["グレゴリオ暦舒明天皇",["Y",628],"(",["Y",0],")"]],[-485004,["グレゴリオ暦皇極天皇",["Y",641],"(",["Y",0],")"]],[-483746,["グレゴリオ暦大化",["Y",644],"(",["Y",0],")"]],[-482037,["グレゴリオ暦白雉",["Y",649],"(",["Y",0],")"]],[-480249,["グレゴリオ暦斉明天皇",["Y",654],"(",["Y",0],")"]],[-477710,["グレゴリオ暦天智天皇",["Y",661],"(",["Y",0],")"]],[-474048,["グレゴリオ暦天武天皇",["Y",671],"(",["Y",0],")"]],[-468743,["グレゴリオ暦朱鳥",["Y",685],"(",["Y",0],")"]],[-468555,["グレゴリオ暦持統天皇",["Y",686],"(",["Y",0],")"]],[-464717,["グレゴリオ暦文武天皇",["Y",696],"(",["Y",0],")"]],[-463367,["グレゴリオ暦大宝",["Y",700],"(",["Y",0],")"]],[-462227,["グレゴリオ暦慶雲",["Y",703],"(",["Y",0],")"]],[-460896,["グレゴリオ暦和銅",["Y",707],"(",["Y",0],")"]],[-458101,["グレゴリオ暦霊亀",["Y",714],"(",["Y",0],")"]],[-457288,["グレゴリオ暦養老",["Y",716],"(",["Y",0],")"]],[-455027,["グレゴリオ暦神亀",["Y",723],"(",["Y",0],")"]],[-453018,["グレゴリオ暦天平",["Y",728],"(",["Y",0],")"]],[-445834,["グレゴリオ暦天平感宝",["Y",748],"(",["Y",0],")"]],[-445727,["グレゴリオ暦天平勝宝",["Y",748],"(",["Y",0],")"]],[-442787,["グレゴリオ暦天平宝字",["Y",756],"(",["Y",0],")"]],[-440082,["グレゴリオ暦天平神護",["Y",764],"(",["Y",0],")"]],[-439128,["グレゴリオ暦神護景雲",["Y",766],"(",["Y",0],")"]],[-437992,["グレゴリオ暦宝亀",["Y",769],"(",["Y",0],")"]],[-434240,["グレゴリオ暦天応",["Y",780],"(",["Y",0],")"]],[-433632,["グレゴリオ暦延暦",["Y",781],"(",["Y",0],")"]],[-424980,["グレゴリオ暦大同",["Y",805],"(",["Y",0],")"]],[-423385,["グレゴリオ暦弘仁",["Y",809],"(",["Y",0],")"]],[-418526,["グレゴリオ暦天長",["Y",823],"(",["Y",0],")"]],[-414867,["グレゴリオ暦承和",["Y",833],"(",["Y",0],")"]],[-409601,["グレゴリオ暦嘉祥",["Y",847],"(",["Y",0],")"]],[-408551,["グレゴリオ暦仁寿",["Y",850],"(",["Y",0],")"]],[-407250,["グレゴリオ暦斉衡",["Y",853],"(",["Y",0],")"]],[-406432,["グレゴリオ暦天安",["Y",856],"(",["Y",0],")"]],[-405641,["グレゴリオ暦貞観",["Y",858],"(",["Y",0],")"]],[-399054,["グレゴリオ暦元慶",["Y",876],"(",["Y",0],")"]],[-396214,["グレゴリオ暦仁和",["Y",884],"(",["Y",0],")"]],[-394673,["グレゴリオ暦寛平",["Y",888],"(",["Y",0],")"]],[-391396,["グレゴリオ暦昌泰",["Y",897],"(",["Y",0],")"]],[-390197,["グレゴリオ暦延喜",["Y",900],"(",["Y",0],")"]],[-382256,["グレゴリオ暦延長",["Y",922],"(",["Y",0],")"]],[-379347,["グレゴリオ暦承平",["Y",930],"(",["Y",0],")"]],[-376753,["グレゴリオ暦天慶",["Y",937],"(",["Y",0],")"]],[-373504,["グレゴリオ暦天暦",["Y",946],"(",["Y",0],")"]],[-369661,["グレゴリオ暦天徳",["Y",956],"(",["Y",0],")"]],[-368461,["グレゴリオ暦応和",["Y",960],"(",["Y",0],")"]],[-367198,["グレゴリオ暦康保",["Y",963],"(",["Y",0],")"]],[-365717,["グレゴリオ暦安和",["Y",967],"(",["Y",0],")"]],[-365115,["グレゴリオ暦天禄",["Y",969],"(",["Y",0],")"]],[-363761,["グレゴリオ暦天延",["Y",972],"(",["Y",0],")"]],[-362823,["グレゴリオ暦貞元",["Y",975],"(",["Y",0],")"]],[-361951,["グレゴリオ暦天元",["Y",977],"(",["Y",0],")"]],[-360341,["グレゴリオ暦永観",["Y",982],"(",["Y",0],")"]],[-359620,["グレゴリオ暦寛和",["Y",984],"(",["Y",0],")"]],[-358904,["グレゴリオ暦永延",["Y",986],"(",["Y",0],")"]],[-358045,["グレゴリオ暦永祚",["Y",988],"(",["Y",0],")"]],[-357603,["グレゴリオ暦正暦",["Y",989],"(",["Y",0],")"]],[-356023,["グレゴリオ暦長徳",["Y",994],"(",["Y",0],")"]],[-354614,["グレゴリオ暦長保",["Y",998],"(",["Y",0],")"]],[-352599,["グレゴリオ暦寛弘",["Y",1003],"(",["Y",0],")"]],[-349493,["グレゴリオ暦長和",["Y",1011],"(",["Y",0],")"]],[-347930,["グレゴリオ暦寛仁",["Y",1016],"(",["Y",0],")"]],[-346534,["グレゴリオ暦治安",["Y",1020],"(",["Y",0],")"]],[-345283,["グレゴリオ暦万寿",["Y",1023],"(",["Y",0],")"]],[-343823,["グレゴリオ暦長元",["Y",1027],"(",["Y",0],")"]],[-340637,["グレゴリオ暦長暦",["Y",1036],"(",["Y",0],")"]],[-339320,["グレゴリオ暦長久",["Y",1039],"(",["Y",0],")"]],[-337859,["グレゴリオ暦寛徳",["Y",1043],"(",["Y",0],")"]],[-337337,["グレゴリオ暦永承",["Y",1045],"(",["Y",0],")"]],[-334889,["グレゴリオ暦天喜",["Y",1052],"(",["Y",0],")"]],[-332834,["グレゴリオ暦康平",["Y",1057],"(",["Y",0],")"]],[-330292,["グレゴリオ暦治暦",["Y",1064],"(",["Y",0],")"]],[-328952,["グレゴリオ暦延久",["Y",1068],"(",["Y",0],")"]],[-326993,["グレゴリオ暦承保",["Y",1073],"(",["Y",0],")"]],[-325817,["グレゴリオ暦承暦",["Y",1076],"(",["Y",0],")"]],[-324614,["グレゴリオ暦永保",["Y",1080],"(",["Y",0],")"]],[-323525,["グレゴリオ暦応徳",["Y",1083],"(",["Y",0],")"]],[-322373,["グレゴリオ暦寛治",["Y",1086],"(",["Y",0],")"]],[-319559,["グレゴリオ暦嘉保",["Y",1093],"(",["Y",0],")"]],[-318848,["グレゴリオ暦永長",["Y",1095],"(",["Y",0],")"]],[-318490,["グレゴリオ暦承徳",["Y",1096],"(",["Y",0],")"]],[-317863,["グレゴリオ暦康和",["Y",1098],"(",["Y",0],")"]],[-316227,["グレゴリオ暦長治",["Y",1103],"(",["Y",0],")"]],[-315431,["グレゴリオ暦嘉承",["Y",1105],"(",["Y",0],")"]],[-314581,["グレゴリオ暦天仁",["Y",1107],"(",["Y",0],")"]],[-313891,["グレゴリオ暦天永",["Y",1109],"(",["Y",0],")"]],[-312770,["グレゴリオ暦永久",["Y",1112],"(",["Y",0],")"]],[-311066,["グレゴリオ暦元永",["Y",1117],"(",["Y",0],")"]],[-310321,["グレゴリオ暦保安",["Y",1119],"(",["Y",0],")"]],[-308851,["グレゴリオ暦天治",["Y",1123],"(",["Y",0],")"]],[-308213,["グレゴリオ暦大治",["Y",1125],"(",["Y",0],")"]],[-306374,["グレゴリオ暦天承",["Y",1130],"(",["Y",0],")"]],[-305803,["グレゴリオ暦長承",["Y",1131],"(",["Y",0],")"]],[-304811,["グレゴリオ暦保延",["Y",1134],"(",["Y",0],")"]],[-302555,["グレゴリオ暦永治",["Y",1140],"(",["Y",0],")"]],[-302270,["グレゴリオ暦康治",["Y",1141],"(",["Y",0],")"]],[-301597,["グレゴリオ暦天養",["Y",1143],"(",["Y",0],")"]],[-301095,["グレゴリオ暦久安",["Y",1144],"(",["Y",0],")"]],[-299083,["グレゴリオ暦仁平",["Y",1150],"(",["Y",0],")"]],[-297694,["グレゴリオ暦久寿",["Y",1153],"(",["Y",0],")"]],[-297163,["グレゴリオ暦保元",["Y",1155],"(",["Y",0],")"]],[-296077,["グレゴリオ暦平治",["Y",1158],"(",["Y",0],")"]],[-295792,["グレゴリオ暦永暦",["Y",1159],"(",["Y",0],")"]],[-295208,["グレゴリオ暦応保",["Y",1160],"(",["Y",0],")"]],[-294621,["グレゴリオ暦長寛",["Y",1162],"(",["Y",0],")"]],[-293819,["グレゴリオ暦永万",["Y",1164],"(",["Y",0],")"]],[-293383,["グレゴリオ暦仁安",["Y",1165],"(",["Y",0],")"]],[-292427,["グレゴリオ暦嘉応",["Y",1168],"(",["Y",0],")"]],[-291676,["グレゴリオ暦承安",["Y",1170],"(",["Y",0],")"]],[-290134,["グレゴリオ暦安元",["Y",1174],"(",["Y",0],")"]],[-289390,["グレゴリオ暦治承",["Y",1176],"(",["Y",0],")"]],[-287933,["グレゴリオ暦養和",["Y",1180],"(",["Y",0],")"]],[-287625,["グレゴリオ暦寿永",["Y",1181],"(",["Y",0],")"]],[-286927,["グレゴリオ暦元暦",["Y",1183],"(",["Y",0],")"]],[-286457,["グレゴリオ暦文治",["Y",1184],"(",["Y",0],")"]],[-284747,["グレゴリオ暦建久",["Y",1189],"(",["Y",0],")"]],[-281453,["グレゴリオ暦正治",["Y",1198],"(",["Y",0],")"]],[-280787,["グレゴリオ暦建仁",["Y",1200],"(",["Y",0],")"]],[-279687,["グレゴリオ暦元久",["Y",1203],"(",["Y",0],")"]],[-278883,["グレゴリオ暦建永",["Y",1205],"(",["Y",0],")"]],[-278354,["グレゴリオ暦承元",["Y",1206],"(",["Y",0],")"]],[-277100,["グレゴリオ暦建暦",["Y",1210],"(",["Y",0],")"]],[-276099,["グレゴリオ暦建保",["Y",1212],"(",["Y",0],")"]],[-274144,["グレゴリオ暦承久",["Y",1218],"(",["Y",0],")"]],[-273050,["グレゴリオ暦貞応",["Y",1221],"(",["Y",0],")"]],[-272099,["グレゴリオ暦元仁",["Y",1223],"(",["Y",0],")"]],[-271951,["グレゴリオ暦嘉禄",["Y",1224],"(",["Y",0],")"]],[-270986,["グレゴリオ暦安貞",["Y",1226],"(",["Y",0],")"]],[-270548,["グレゴリオ暦寛喜",["Y",1228],"(",["Y",0],")"]],[-269429,["グレゴリオ暦貞永",["Y",1231],"(",["Y",0],")"]],[-269032,["グレゴリオ暦天福",["Y",1232],"(",["Y",0],")"]],[-268481,["グレゴリオ暦文暦",["Y",1233],"(",["Y",0],")"]],[-268142,["グレゴリオ暦嘉禎",["Y",1234],"(",["Y",0],")"]],[-266987,["グレゴリオ暦暦仁",["Y",1237],"(",["Y",0],")"]],[-266914,["グレゴリオ暦延応",["Y",1238],"(",["Y",0],")"]],[-266403,["グレゴリオ暦仁治",["Y",1239],"(",["Y",0],")"]],[-265448,["グレゴリオ暦寛元",["Y",1242],"(",["Y",0],")"]],[-263969,["グレゴリオ暦宝治",["Y",1246],"(",["Y",0],")"]],[-263211,["グレゴリオ暦建長",["Y",1248],"(",["Y",0],")"]],[-260479,["グレゴリオ暦康元",["Y",1255],"(",["Y",0],")"]],[-260321,["グレゴリオ暦正嘉",["Y",1256],"(",["Y",0],")"]],[-259571,["グレゴリオ暦正元",["Y",1258],"(",["Y",0],")"]],[-259171,["グレゴリオ暦文応",["Y",1259],"(",["Y",0],")"]],[-258869,["グレゴリオ暦弘長",["Y",1260],"(",["Y",0],")"]],[-257768,["グレゴリオ暦文永",["Y",1263],"(",["Y",0],")"]],[-253695,["グレゴリオ暦建治",["Y",1274],"(",["Y",0],")"]],[-252659,["グレゴリオ暦弘安",["Y",1277],"(",["Y",0],")"]],[-248939,["グレゴリオ暦正応",["Y",1287],"(",["Y",0],")"]],[-247013,["グレゴリオ暦永仁",["Y",1292],"(",["Y",0],")"]],[-244926,["グレゴリオ暦正安",["Y",1298],"(",["Y",0],")"]],[-243631,["グレゴリオ暦乾元",["Y",1301],"(",["Y",0],")"]],[-243351,["グレゴリオ暦嘉元",["Y",1302],"(",["Y",0],")"]],[-242131,["グレゴリオ暦徳治",["Y",1305],"(",["Y",0],")"]],[-241457,["グレゴリオ暦延慶",["Y",1307],"(",["Y",0],")"]],[-240551,["グレゴリオ暦応長",["Y",1310],"(",["Y",0],")"]],[-240205,["グレゴリオ暦正和",["Y",1311],"(",["Y",0],")"]],[-238421,["グレゴリオ暦文保",["Y",1316],"(",["Y",0],")"]],[-237628,["グレゴリオ暦元応",["Y",1318],"(",["Y",0],")"]],[-236954,["グレゴリオ暦元亨",["Y",1320],"(",["Y",0],")"]],[-235580,["グレゴリオ暦正中",["Y",1323],"(",["Y",0],")"]],[-235061,["グレゴリオ暦嘉暦",["Y",1325],"(",["Y",0],")"]],[-233848,["グレゴリオ暦元徳",["Y",1328],"(",["Y",0],")"]],[-233129,["グレゴリオ暦元弘",["Y",1330],"/元徳",["Y",1328],"(",["Y",0],")"]],[-232874,["グレゴリオ暦元弘",["Y",1330],"/正慶",["Y",1331],"(",["Y",0],")"]],[-232464,["グレゴリオ暦元弘",["Y",1330],"(",["Y",0],")"]],[-232223,["グレゴリオ暦建武",["Y",1333],"(",["Y",0],")"]],[-231455,["グレゴリオ暦延元",["Y",1335],"(",["Y",0],")"]],[-231352,["グレゴリオ暦延元",["Y",1335],"/建武",["Y",1333],"(",["Y",0],")"]],[-230542,["グレゴリオ暦延元",["Y",1335],"/暦応",["Y",1337],"(",["Y",0],")"]],[-229950,["グレゴリオ暦興国",["Y",1339],"/暦応",["Y",1337],"(",["Y",0],")"]],[-229213,["グレゴリオ暦興国",["Y",1339],"/康永",["Y",1341],"(",["Y",0],")"]],[-227950,["グレゴリオ暦興国",["Y",1339],"/貞和",["Y",1344],"(",["Y",0],")"]],[-227519,["グレゴリオ暦正平",["Y",1345],"/貞和",["Y",1344],"(",["Y",0],")"]],[-226349,["グレゴリオ暦正平",["Y",1345],"/観応",["Y",1349],"(",["Y",0],")"]],[-225748,["グレゴリオ暦正平",["Y",1345],"(",["Y",0],")"]],[-225593,["グレゴリオ暦正平",["Y",1345],"/観応",["Y",1349],"(",["Y",0],")"]],[-225404,["グレゴリオ暦正平",["Y",1345],"/文和",["Y",1351],"(",["Y",0],")"]],[-224132,["グレゴリオ暦正平",["Y",1345],"/延文",["Y",1355],"(",["Y",0],")"]],[-222301,["グレゴリオ暦正平",["Y",1345],"/康安",["Y",1360],"(",["Y",0],")"]],[-221776,["グレゴリオ暦正平",["Y",1345],"/貞治",["Y",1361],"(",["Y",0],")"]],[-219802,["グレゴリオ暦正平",["Y",1345],"/応安",["Y",1367],"(",["Y",0],")"]],[-219076,["グレゴリオ暦建徳",["Y",1369],"/応安",["Y",1367],"(",["Y",0],")"]],[-218256,["グレゴリオ暦文中",["Y",1371],"/応安",["Y",1367],"(",["Y",0],")"]],[-217224,["グレゴリオ暦文中",["Y",1371],"/永和",["Y",1374],"(",["Y",0],")"]],[-217135,["グレゴリオ暦天授",["Y",1374],"/永和",["Y",1374],"(",["Y",0],")"]],[-215752,["グレゴリオ暦天授",["Y",1374],"/康暦",["Y",1378],"(",["Y",0],")"]],[-215055,["グレゴリオ暦弘和",["Y",1380],"/康暦",["Y",1378],"(",["Y",0],")"]],[-215041,["グレゴリオ暦弘和",["Y",1380],"/永徳",["Y",1380],"(",["Y",0],")"]],[-213946,["グレゴリオ暦弘和",["Y",1380],"/至徳",["Y",1383],"(",["Y",0],")"]],[-213886,["グレゴリオ暦元中",["Y",1383],"/至徳",["Y",1383],"(",["Y",0],")"]],[-212651,["グレゴリオ暦元中",["Y",1383],"/嘉慶",["Y",1386],"(",["Y",0],")"]],[-212132,["グレゴリオ暦元中",["Y",1383],"/康応",["Y",1388],"(",["Y",0],")"]],[-211731,["グレゴリオ暦元中",["Y",1383],"/明徳",["Y",1389],"(",["Y",0],")"]],[-210779,["グレゴリオ暦明徳",["Y",1389],"(",["Y",0],")"]],[-210158,["グレゴリオ暦応永",["Y",1393],"(",["Y",0],")"]],[-197792,["グレゴリオ暦正長",["Y",1427],"(",["Y",0],")"]],[-197312,["グレゴリオ暦永享",["Y",1428],"(",["Y",0],")"]],[-193136,["グレゴリオ暦嘉吉",["Y",1440],"(",["Y",0],")"]],[-192056,["グレゴリオ暦文安",["Y",1443],"(",["Y",0],")"]],[-190055,["グレゴリオ暦宝徳",["Y",1448],"(",["Y",0],")"]],[-188965,["グレゴリオ暦享徳",["Y",1451],"(",["Y",0],")"]],[-187843,["グレゴリオ暦康正",["Y",1454],"(",["Y",0],")"]],[-187072,["グレゴリオ暦長禄",["Y",1456],"(",["Y",0],")"]],[-185868,["グレゴリオ暦寛正",["Y",1459],"(",["Y",0],")"]],[-184001,["グレゴリオ暦文正",["Y",1465],"(",["Y",0],")"]],[-183610,["グレゴリオ暦応仁",["Y",1466],"(",["Y",0],")"]],[-182819,["グレゴリオ暦文明",["Y",1468],"(",["Y",0],")"]],[-176183,["グレゴリオ暦長享",["Y",1486],"(",["Y",0],")"]],[-175414,["グレゴリオ暦延徳",["Y",1488],"(",["Y",0],")"]],[-174353,["グレゴリオ暦明応",["Y",1491],"(",["Y",0],")"]],[-171213,["グレゴリオ暦文亀",["Y",1500],"(",["Y",0],")"]],[-170119,["グレゴリオ暦永正",["Y",1503],"(",["Y",0],")"]],[-163719,["グレゴリオ暦大永",["Y",1520],"(",["Y",0],")"]],[-161182,["グレゴリオ暦享禄",["Y",1527],"(",["Y",0],")"]],[-159726,["グレゴリオ暦天文",["Y",1531],"(",["Y",0],")"]],[-151256,["グレゴリオ暦弘治",["Y",1554],"(",["Y",0],")"]],[-150394,["グレゴリオ暦永禄",["Y",1557],"(",["Y",0],")"]],[-145941,["グレゴリオ暦元亀",["Y",1569],"(",["Y",0],")"]],[-144755,["グレゴリオ暦天正",["Y",1572],"(",["Y",0],")"]],[-137687,["グレゴリオ暦文禄",["Y",1591],"(",["Y",0],")"]],[-136251,["グレゴリオ暦慶長",["Y",1595],"(",["Y",0],")"]],[-129414,["グレゴリオ暦元和",["Y",1614],"(",["Y",0],")"]],[-126267,["グレゴリオ暦寛永",["Y",1623],"(",["Y",0],")"]],[-118691,["グレゴリオ暦正保",["Y",1643],"(",["Y",0],")"]],[-117511,["グレゴリオ暦慶安",["Y",1647],"(",["Y",0],")"]],[-115854,["グレゴリオ暦承応",["Y",1651],"(",["Y",0],")"]],[-114914,["グレゴリオ暦明暦",["Y",1654],"(",["Y",0],")"]],[-113723,["グレゴリオ暦万治",["Y",1657],"(",["Y",0],")"]],[-112717,["グレゴリオ暦寛文",["Y",1660],"(",["Y",0],")"]],[-108174,["グレゴリオ暦延宝",["Y",1672],"(",["Y",0],")"]],[-105242,["グレゴリオ暦天和",["Y",1680],"(",["Y",0],")"]],[-104364,["グレゴリオ暦貞享",["Y",1683],"(",["Y",0],")"]],[-102702,["グレゴリオ暦元禄",["Y",1687],"(",["Y",0],")"]],[-97049,["グレゴリオ暦宝永",["Y",1703],"(",["Y",0],")"]],[-94437,["グレゴリオ暦正徳",["Y",1710],"(",["Y",0],")"]],[-92551,["グレゴリオ暦享保",["Y",1715],"(",["Y",0],")"]],[-85309,["グレゴリオ暦元文",["Y",1735],"(",["Y",0],")"]],[-83539,["グレゴリオ暦寛保",["Y",1740],"(",["Y",0],")"]],[-82452,["グレゴリオ暦延享",["Y",1743],"(",["Y",0],")"]],[-80867,["グレゴリオ暦寛延",["Y",1747],"(",["Y",0],")"]],[-79641,["グレゴリオ暦宝暦",["Y",1750],"(",["Y",0],")"]],[-75059,["グレゴリオ暦明和",["Y",1763],"(",["Y",0],")"]],[-71974,["グレゴリオ暦安永",["Y",1771],"(",["Y",0],")"]],[-68916,["グレゴリオ暦天明",["Y",1780],"(",["Y",0],")"]],[-66059,["グレゴリオ暦寛政",["Y",1788],"(",["Y",0],")"]],[-61649,["グレゴリオ暦享和",["Y",1800],"(",["Y",0],")"]],[-60550,["グレゴリオ暦文化",["Y",1803],"(",["Y",0],")"]],[-55372,["グレゴリオ暦文政",["Y",1817],"(",["Y",0],")"]],[-50747,["グレゴリオ暦天保",["Y",1829],"(",["Y",0],")"]],[-45647,["グレゴリオ暦弘化",["Y",1843],"(",["Y",0],")"]],[-44469,["グレゴリオ暦嘉永",["Y",1847],"(",["Y",0],")"]],[-41989,["グレゴリオ暦安政",["Y",1853],"(",["Y",0],")"]],[-40079,["グレゴリオ暦万延",["Y",1859],"(",["Y",0],")"]],[-39724,["グレゴリオ暦文久",["Y",1860],"(",["Y",0],")"]],[-38630,["グレゴリオ暦元治",["Y",1863],"(",["Y",0],")"]],[-38230,["グレゴリオ暦慶応",["Y",1864],"(",["Y",0],")"]],[-36959,["グレゴリオ暦明治",["Y",1867],"(",["Y",0],")"]],[-35428,["明治",["Y",1867],"(",["Y",0],")"]],[-20974,["大正",["Y",1911],"(",["Y",0],")"]],[-15713,["昭和",["Y",1925],"(",["Y",0],")"]],[6947,["平成",["Y",1988],"(",["Y",0],")"]],[18017,["令和",["Y",2018],"(",["Y",0],")"]]],"dtsjp2":[[null,["グレゴリオ暦西暦",["y",0]]],[-962750,["グレゴリオ暦神武天皇即位前",["k"],"(",["y",0],")"]],[-960181,["グレゴリオ暦神武",["y",-660],"(",["y",0],")"]],[-931329,["グレゴリオ暦綏靖",["y",-581],"(",["y",0],")"]],[-919281,["グレゴリオ暦安寧",["y",-548],"(",["y",0],")"]],[-905401,["グレゴリオ暦懿徳",["y",-510],"(",["y",0],")"]],[-892615,["グレゴリオ暦孝昭",["y",-475],"(",["y",0],")"]],[-862316,["グレゴリオ暦孝安",["y",-392],"(",["y",0],")"]],[-825049,["グレゴリオ暦孝霊",["y",-290],"(",["y",0],")"]],[-797290,["グレゴリオ暦孝元",["y",-214],"(",["y",0],")"]],[-776471,["グレゴリオ暦開化",["y",-157],"(",["y",0],")"]],[-754559,["グレゴリオ暦崇神",["y",-97],"(",["y",0],")"]],[-729724,["グレゴリオ暦垂仁",["y",-29],"(",["y",0],")"]],[-693549,["グレゴリオ暦景行",["y",70],"(",["y",0],")"]],[-671637,["グレゴリオ暦成務",["y",130],"(",["y",0],")"]],[-649371,["グレゴリオ暦仲哀",["y",191],"(",["y",0],")"]],[-646093,["グレゴリオ暦神功",["y",200],"(",["y",0],")"]],[-620874,["グレゴリオ暦応神",["y",269],"(",["y",0],")"]],[-605164,["グレゴリオ暦仁徳",["y",312],"(",["y",0],")"]],[-573389,["グレゴリオ暦履中",["y",399],"(",["y",0],")"]],[-571204,["グレゴリオ暦反正",["y",405],"(",["y",0],")"]],[-569018,["グレゴリオ暦允恭",["y",411],"(",["y",0],")"]],[-553662,["グレゴリオ暦安康",["y",453],"(",["y",0],")"]],[-552570,["グレゴリオ暦雄略",["y",456],"(",["y",0],")"]],[-544183,["グレゴリオ暦清寧",["y",479],"(",["y",0],")"]],[-542352,["グレゴリオ暦顕宗",["y",484],"(",["y",0],")"]],[-541260,["グレゴリオ暦仁賢",["y",487],"(",["y",0],")"]],[-537243,["グレゴリオ暦武烈",["y",498],"(",["y",0],")"]],[-534320,["グレゴリオ暦継体",["y",506],"(",["y",0],")"]],[-524457,["グレゴリオ暦安閑",["y",533],"(",["y",0],")"]],[-523718,["グレゴリオ暦宣化",["y",535],"(",["y",0],")"]],[-522271,["グレゴリオ暦欽明",["y",539],"(",["y",0],")"]],[-510577,["グレゴリオ暦敏達",["y",571],"(",["y",0],")"]],[-505469,["グレゴリオ暦用明",["y",585],"(",["y",0],")"]],[-504730,["グレゴリオ暦崇峻",["y",587],"(",["y",0],")"]],[-502899,["グレゴリオ暦推古",["y",592],"(",["y",0],")"]],[-489758,["グレゴリオ暦舒明",["y",628],"(",["y",0],")"]],[-485004,["グレゴリオ暦皇極",["y",641],"(",["y",0],")"]],[-483746,["グレゴリオ暦大化",["y",644],"(",["y",0],")"]],[-482037,["グレゴリオ暦白雉",["y",649],"(",["y",0],")"]],[-480249,["グレゴリオ暦斉明",["y",654],"(",["y",0],")"]],[-477710,["グレゴリオ暦天智",["y",661],"(",["y",0],")"]],[-474048,["グレゴリオ暦天武",["y",671],"(",["y",0],")"]],[-468743,["グレゴリオ暦朱鳥",["y",685],"(",["y",0],")"]],[-468555,["グレゴリオ暦持統",["y",686],"(",["y",0],")"]],[-464717,["グレゴリオ暦文武",["y",696],"(",["y",0],")"]],[-463367,["グレゴリオ暦大宝",["y",700],"(",["y",0],")"]],[-462227,["グレゴリオ暦慶雲",["y",703],"(",["y",0],")"]],[-460896,["グレゴリオ暦和銅",["y",707],"(",["y",0],")"]],[-458101,["グレゴリオ暦霊亀",["y",714],"(",["y",0],")"]],[-457288,["グレゴリオ暦養老",["y",716],"(",["y",0],")"]],[-455027,["グレゴリオ暦神亀",["y",723],"(",["y",0],")"]],[-453018,["グレゴリオ暦天平",["y",728],"(",["y",0],")"]],[-445834,["グレゴリオ暦天平感宝",["y",748],"(",["y",0],")"]],[-445727,["グレゴリオ暦天平勝宝",["y",748],"(",["y",0],")"]],[-442787,["グレゴリオ暦天平宝字",["y",756],"(",["y",0],")"]],[-440082,["グレゴリオ暦天平神護",["y",764],"(",["y",0],")"]],[-439128,["グレゴリオ暦神護景雲",["y",766],"(",["y",0],")"]],[-437992,["グレゴリオ暦宝亀",["y",769],"(",["y",0],")"]],[-434240,["グレゴリオ暦天応",["y",780],"(",["y",0],")"]],[-433632,["グレゴリオ暦延暦",["y",781],"(",["y",0],")"]],[-424980,["グレゴリオ暦大同",["y",805],"(",["y",0],")"]],[-423385,["グレゴリオ暦弘仁",["y",809],"(",["y",0],")"]],[-418526,["グレゴリオ暦天長",["y",823],"(",["y",0],")"]],[-414867,["グレゴリオ暦承和",["y",833],"(",["y",0],")"]],[-409601,["グレゴリオ暦嘉祥",["y",847],"(",["y",0],")"]],[-408551,["グレゴリオ暦仁寿",["y",850],"(",["y",0],")"]],[-407250,["グレゴリオ暦斉衡",["y",853],"(",["y",0],")"]],[-406432,["グレゴリオ暦天安",["y",856],"(",["y",0],")"]],[-405641,["グレゴリオ暦貞観",["y",858],"(",["y",0],")"]],[-399054,["グレゴリオ暦元慶",["y",876],"(",["y",0],")"]],[-396214,["グレゴリオ暦仁和",["y",884],"(",["y",0],")"]],[-394673,["グレゴリオ暦寛平",["y",888],"(",["y",0],")"]],[-391396,["グレゴリオ暦昌泰",["y",897],"(",["y",0],")"]],[-390197,["グレゴリオ暦延喜",["y",900],"(",["y",0],")"]],[-382256,["グレゴリオ暦延長",["y",922],"(",["y",0],")"]],[-379347,["グレゴリオ暦承平",["y",930],"(",["y",0],")"]],[-376753,["グレゴリオ暦天慶",["y",937],"(",["y",0],")"]],[-373504,["グレゴリオ暦天暦",["y",946],"(",["y",0],")"]],[-369661,["グレゴリオ暦天徳",["y",956],"(",["y",0],")"]],[-368461,["グレゴリオ暦応和",["y",960],"(",["y",0],")"]],[-367198,["グレゴリオ暦康保",["y",963],"(",["y",0],")"]],[-365717,["グレゴリオ暦安和",["y",967],"(",["y",0],")"]],[-365115,["グレゴリオ暦天禄",["y",969],"(",["y",0],")"]],[-363761,["グレゴリオ暦天延",["y",972],"(",["y",0],")"]],[-362823,["グレゴリオ暦貞元",["y",975],"(",["y",0],")"]],[-361951,["グレゴリオ暦天元",["y",977],"(",["y",0],")"]],[-360341,["グレゴリオ暦永観",["y",982],"(",["y",0],")"]],[-359620,["グレゴリオ暦寛和",["y",984],"(",["y",0],")"]],[-358904,["グレゴリオ暦永延",["y",986],"(",["y",0],")"]],[-358045,["グレゴリオ暦永祚",["y",988],"(",["y",0],")"]],[-357603,["グレゴリオ暦正暦",["y",989],"(",["y",0],")"]],[-356023,["グレゴリオ暦長徳",["y",994],"(",["y",0],")"]],[-354614,["グレゴリオ暦長保",["y",998],"(",["y",0],")"]],[-352599,["グレゴリオ暦寛弘",["y",1003],"(",["y",0],")"]],[-349493,["グレゴリオ暦長和",["y",1011],"(",["y",0],")"]],[-347930,["グレゴリオ暦寛仁",["y",1016],"(",["y",0],")"]],[-346534,["グレゴリオ暦治安",["y",1020],"(",["y",0],")"]],[-345283,["グレゴリオ暦万寿",["y",1023],"(",["y",0],")"]],[-343823,["グレゴリオ暦長元",["y",1027],"(",["y",0],")"]],[-340637,["グレゴリオ暦長暦",["y",1036],"(",["y",0],")"]],[-339320,["グレゴリオ暦長久",["y",1039],"(",["y",0],")"]],[-337859,["グレゴリオ暦寛徳",["y",1043],"(",["y",0],")"]],[-337337,["グレゴリオ暦永承",["y",1045],"(",["y",0],")"]],[-334889,["グレゴリオ暦天喜",["y",1052],"(",["y",0],")"]],[-332834,["グレゴリオ暦康平",["y",1057],"(",["y",0],")"]],[-330292,["グレゴリオ暦治暦",["y",1064],"(",["y",0],")"]],[-328952,["グレゴリオ暦延久",["y",1068],"(",["y",0],")"]],[-326993,["グレゴリオ暦承保",["y",1073],"(",["y",0],")"]],[-325817,["グレゴリオ暦承暦",["y",1076],"(",["y",0],")"]],[-324614,["グレゴリオ暦永保",["y",1080],"(",["y",0],")"]],[-323525,["グレゴリオ暦応徳",["y",1083],"(",["y",0],")"]],[-322373,["グレゴリオ暦寛治",["y",1086],"(",["y",0],")"]],[-319559,["グレゴリオ暦嘉保",["y",1093],"(",["y",0],")"]],[-318848,["グレゴリオ暦永長",["y",1095],"(",["y",0],")"]],[-318490,["グレゴリオ暦承徳",["y",1096],"(",["y",0],")"]],[-317863,["グレゴリオ暦康和",["y",1098],"(",["y",0],")"]],[-316227,["グレゴリオ暦長治",["y",1103],"(",["y",0],")"]],[-315431,["グレゴリオ暦嘉承",["y",1105],"(",["y",0],")"]],[-314581,["グレゴリオ暦天仁",["y",1107],"(",["y",0],")"]],[-313891,["グレゴリオ暦天永",["y",1109],"(",["y",0],")"]],[-312770,["グレゴリオ暦永久",["y",1112],"(",["y",0],")"]],[-311066,["グレゴリオ暦元永",["y",1117],"(",["y",0],")"]],[-310321,["グレゴリオ暦保安",["y",1119],"(",["y",0],")"]],[-308851,["グレゴリオ暦天治",["y",1123],"(",["y",0],")"]],[-308213,["グレゴリオ暦大治",["y",1125],"(",["y",0],")"]],[-306374,["グレゴリオ暦天承",["y",1130],"(",["y",0],")"]],[-305803,["グレゴリオ暦長承",["y",1131],"(",["y",0],")"]],[-304811,["グレゴリオ暦保延",["y",1134],"(",["y",0],")"]],[-302555,["グレゴリオ暦永治",["y",1140],"(",["y",0],")"]],[-302270,["グレゴリオ暦康治",["y",1141],"(",["y",0],")"]],[-301597,["グレゴリオ暦天養",["y",1143],"(",["y",0],")"]],[-301095,["グレゴリオ暦久安",["y",1144],"(",["y",0],")"]],[-299083,["グレゴリオ暦仁平",["y",1150],"(",["y",0],")"]],[-297694,["グレゴリオ暦久寿",["y",1153],"(",["y",0],")"]],[-297163,["グレゴリオ暦保元",["y",1155],"(",["y",0],")"]],[-296077,["グレゴリオ暦平治",["y",1158],"(",["y",0],")"]],[-295792,["グレゴリオ暦永暦",["y",1159],"(",["y",0],")"]],[-295208,["グレゴリオ暦応保",["y",1160],"(",["y",0],")"]],[-294621,["グレゴリオ暦長寛",["y",1162],"(",["y",0],")"]],[-293819,["グレゴリオ暦永万",["y",1164],"(",["y",0],")"]],[-293383,["グレゴリオ暦仁安",["y",1165],"(",["y",0],")"]],[-292427,["グレゴリオ暦嘉応",["y",1168],"(",["y",0],")"]],[-291676,["グレゴリオ暦承安",["y",1170],"(",["y",0],")"]],[-290134,["グレゴリオ暦安元",["y",1174],"(",["y",0],")"]],[-289390,["グレゴリオ暦治承",["y",1176],"(",["y",0],")"]],[-287933,["グレゴリオ暦養和",["y",1180],"(",["y",0],")"]],[-287625,["グレゴリオ暦寿永",["y",1181],"(",["y",0],")"]],[-286927,["グレゴリオ暦元暦",["y",1183],"(",["y",0],")"]],[-286457,["グレゴリオ暦文治",["y",1184],"(",["y",0],")"]],[-284747,["グレゴリオ暦建久",["y",1189],"(",["y",0],")"]],[-281453,["グレゴリオ暦正治",["y",1198],"(",["y",0],")"]],[-280787,["グレゴリオ暦建仁",["y",1200],"(",["y",0],")"]],[-279687,["グレゴリオ暦元久",["y",1203],"(",["y",0],")"]],[-278883,["グレゴリオ暦建永",["y",1205],"(",["y",0],")"]],[-278354,["グレゴリオ暦承元",["y",1206],"(",["y",0],")"]],[-277100,["グレゴリオ暦建暦",["y",1210],"(",["y",0],")"]],[-276099,["グレゴリオ暦建保",["y",1212],"(",["y",0],")"]],[-274144,["グレゴリオ暦承久",["y",1218],"(",["y",0],")"]],[-273050,["グレゴリオ暦貞応",["y",1221],"(",["y",0],")"]],[-272099,["グレゴリオ暦元仁",["y",1223],"(",["y",0],")"]],[-271951,["グレゴリオ暦嘉禄",["y",1224],"(",["y",0],")"]],[-270986,["グレゴリオ暦安貞",["y",1226],"(",["y",0],")"]],[-270548,["グレゴリオ暦寛喜",["y",1228],"(",["y",0],")"]],[-269429,["グレゴリオ暦貞永",["y",1231],"(",["y",0],")"]],[-269032,["グレゴリオ暦天福",["y",1232],"(",["y",0],")"]],[-268481,["グレゴリオ暦文暦",["y",1233],"(",["y",0],")"]],[-268142,["グレゴリオ暦嘉禎",["y",1234],"(",["y",0],")"]],[-266987,["グレゴリオ暦暦仁",["y",1237],"(",["y",0],")"]],[-266914,["グレゴリオ暦延応",["y",1238],"(",["y",0],")"]],[-266403,["グレゴリオ暦仁治",["y",1239],"(",["y",0],")"]],[-265448,["グレゴリオ暦寛元",["y",1242],"(",["y",0],")"]],[-263969,["グレゴリオ暦宝治",["y",1246],"(",["y",0],")"]],[-263211,["グレゴリオ暦建長",["y",1248],"(",["y",0],")"]],[-260479,["グレゴリオ暦康元",["y",1255],"(",["y",0],")"]],[-260321,["グレゴリオ暦正嘉",["y",1256],"(",["y",0],")"]],[-259571,["グレゴリオ暦正元",["y",1258],"(",["y",0],")"]],[-259171,["グレゴリオ暦文応",["y",1259],"(",["y",0],")"]],[-258869,["グレゴリオ暦弘長",["y",1260],"(",["y",0],")"]],[-257768,["グレゴリオ暦文永",["y",1263],"(",["y",0],")"]],[-253695,["グレゴリオ暦建治",["y",1274],"(",["y",0],")"]],[-252659,["グレゴリオ暦弘安",["y",1277],"(",["y",0],")"]],[-248939,["グレゴリオ暦正応",["y",1287],"(",["y",0],")"]],[-247013,["グレゴリオ暦永仁",["y",1292],"(",["y",0],")"]],[-244926,["グレゴリオ暦正安",["y",1298],"(",["y",0],")"]],[-243631,["グレゴリオ暦乾元",["y",1301],"(",["y",0],")"]],[-243351,["グレゴリオ暦嘉元",["y",1302],"(",["y",0],")"]],[-242131,["グレゴリオ暦徳治",["y",1305],"(",["y",0],")"]],[-241457,["グレゴリオ暦延慶",["y",1307],"(",["y",0],")"]],[-240551,["グレゴリオ暦応長",["y",1310],"(",["y",0],")"]],[-240205,["グレゴリオ暦正和",["y",1311],"(",["y",0],")"]],[-238421,["グレゴリオ暦文保",["y",1316],"(",["y",0],")"]],[-237628,["グレゴリオ暦元応",["y",1318],"(",["y",0],")"]],[-236954,["グレゴリオ暦元亨",["y",1320],"(",["y",0],")"]],[-235580,["グレゴリオ暦正中",["y",1323],"(",["y",0],")"]],[-235061,["グレゴリオ暦嘉暦",["y",1325],"(",["y",0],")"]],[-233848,["グレゴリオ暦元徳",["y",1328],"(",["y",0],")"]],[-233129,["グレゴリオ暦元弘",["y",1330],"/元徳",["y",1328],"(",["y",0],")"]],[-232874,["グレゴリオ暦元弘",["y",1330],"/正慶",["y",1331],"(",["y",0],")"]],[-232464,["グレゴリオ暦元弘",["y",1330],"(",["y",0],")"]],[-232223,["グレゴリオ暦建武",["y",1333],"(",["y",0],")"]],[-231455,["グレゴリオ暦延元",["y",1335],"(",["y",0],")"]],[-231352,["グレゴリオ暦延元",["y",1335],"/建武",["y",1333],"(",["y",0],")"]],[-230542,["グレゴリオ暦延元",["y",1335],"/暦応",["y",1337],"(",["y",0],")"]],[-229950,["グレゴリオ暦興国",["y",1339],"/暦応",["y",1337],"(",["y",0],")"]],[-229213,["グレゴリオ暦興国",["y",1339],"/康永",["y",1341],"(",["y",0],")"]],[-227950,["グレゴリオ暦興国",["y",1339],"/貞和",["y",1344],"(",["y",0],")"]],[-227519,["グレゴリオ暦正平",["y",1345],"/貞和",["y",1344],"(",["y",0],")"]],[-226349,["グレゴリオ暦正平",["y",1345],"/観応",["y",1349],"(",["y",0],")"]],[-225748,["グレゴリオ暦正平",["y",1345],"(",["y",0],")"]],[-225593,["グレゴリオ暦正平",["y",1345],"/観応",["y",1349],"(",["y",0],")"]],[-225404,["グレゴリオ暦正平",["y",1345],"/文和",["y",1351],"(",["y",0],")"]],[-224132,["グレゴリオ暦正平",["y",1345],"/延文",["y",1355],"(",["y",0],")"]],[-222301,["グレゴリオ暦正平",["y",1345],"/康安",["y",1360],"(",["y",0],")"]],[-221776,["グレゴリオ暦正平",["y",1345],"/貞治",["y",1361],"(",["y",0],")"]],[-219802,["グレゴリオ暦正平",["y",1345],"/応安",["y",1367],"(",["y",0],")"]],[-219076,["グレゴリオ暦建徳",["y",1369],"/応安",["y",1367],"(",["y",0],")"]],[-218256,["グレゴリオ暦文中",["y",1371],"/応安",["y",1367],"(",["y",0],")"]],[-217224,["グレゴリオ暦文中",["y",1371],"/永和",["y",1374],"(",["y",0],")"]],[-217135,["グレゴリオ暦天授",["y",1374],"/永和",["y",1374],"(",["y",0],")"]],[-215752,["グレゴリオ暦天授",["y",1374],"/康暦",["y",1378],"(",["y",0],")"]],[-215055,["グレゴリオ暦弘和",["y",1380],"/康暦",["y",1378],"(",["y",0],")"]],[-215041,["グレゴリオ暦弘和",["y",1380],"/永徳",["y",1380],"(",["y",0],")"]],[-213946,["グレゴリオ暦弘和",["y",1380],"/至徳",["y",1383],"(",["y",0],")"]],[-213886,["グレゴリオ暦元中",["y",1383],"/至徳",["y",1383],"(",["y",0],")"]],[-212651,["グレゴリオ暦元中",["y",1383],"/嘉慶",["y",1386],"(",["y",0],")"]],[-212132,["グレゴリオ暦元中",["y",1383],"/康応",["y",1388],"(",["y",0],")"]],[-211731,["グレゴリオ暦元中",["y",1383],"/明徳",["y",1389],"(",["y",0],")"]],[-210779,["グレゴリオ暦明徳",["y",1389],"(",["y",0],")"]],[-210158,["グレゴリオ暦応永",["y",1393],"(",["y",0],")"]],[-197792,["グレゴリオ暦正長",["y",1427],"(",["y",0],")"]],[-197312,["グレゴリオ暦永享",["y",1428],"(",["y",0],")"]],[-193136,["グレゴリオ暦嘉吉",["y",1440],"(",["y",0],")"]],[-192056,["グレゴリオ暦文安",["y",1443],"(",["y",0],")"]],[-190055,["グレゴリオ暦宝徳",["y",1448],"(",["y",0],")"]],[-188965,["グレゴリオ暦享徳",["y",1451],"(",["y",0],")"]],[-187843,["グレゴリオ暦康正",["y",1454],"(",["y",0],")"]],[-187072,["グレゴリオ暦長禄",["y",1456],"(",["y",0],")"]],[-185868,["グレゴリオ暦寛正",["y",1459],"(",["y",0],")"]],[-184001,["グレゴリオ暦文正",["y",1465],"(",["y",0],")"]],[-183610,["グレゴリオ暦応仁",["y",1466],"(",["y",0],")"]],[-182819,["グレゴリオ暦文明",["y",1468],"(",["y",0],")"]],[-176183,["グレゴリオ暦長享",["y",1486],"(",["y",0],")"]],[-175414,["グレゴリオ暦延徳",["y",1488],"(",["y",0],")"]],[-174353,["グレゴリオ暦明応",["y",1491],"(",["y",0],")"]],[-171213,["グレゴリオ暦文亀",["y",1500],"(",["y",0],")"]],[-170119,["グレゴリオ暦永正",["y",1503],"(",["y",0],")"]],[-163719,["グレゴリオ暦大永",["y",1520],"(",["y",0],")"]],[-161182,["グレゴリオ暦享禄",["y",1527],"(",["y",0],")"]],[-159726,["グレゴリオ暦天文",["y",1531],"(",["y",0],")"]],[-151256,["グレゴリオ暦弘治",["y",1554],"(",["y",0],")"]],[-150394,["グレゴリオ暦永禄",["y",1557],"(",["y",0],")"]],[-145941,["グレゴリオ暦元亀",["y",1569],"(",["y",0],")"]],[-144755,["グレゴリオ暦天正",["y",1572],"(",["y",0],")"]],[-137687,["グレゴリオ暦文禄",["y",1591],"(",["y",0],")"]],[-136251,["グレゴリオ暦慶長",["y",1595],"(",["y",0],")"]],[-129414,["グレゴリオ暦元和",["y",1614],"(",["y",0],")"]],[-126267,["グレゴリオ暦寛永",["y",1623],"(",["y",0],")"]],[-118691,["グレゴリオ暦正保",["y",1643],"(",["y",0],")"]],[-117511,["グレゴリオ暦慶安",["y",1647],"(",["y",0],")"]],[-115854,["グレゴリオ暦承応",["y",1651],"(",["y",0],")"]],[-114914,["グレゴリオ暦明暦",["y",1654],"(",["y",0],")"]],[-113723,["グレゴリオ暦万治",["y",1657],"(",["y",0],")"]],[-112717,["グレゴリオ暦寛文",["y",1660],"(",["y",0],")"]],[-108174,["グレゴリオ暦延宝",["y",1672],"(",["y",0],")"]],[-105242,["グレゴリオ暦天和",["y",1680],"(",["y",0],")"]],[-104364,["グレゴリオ暦貞享",["y",1683],"(",["y",0],")"]],[-102702,["グレゴリオ暦元禄",["y",1687],"(",["y",0],")"]],[-97049,["グレゴリオ暦宝永",["y",1703],"(",["y",0],")"]],[-94437,["グレゴリオ暦正徳",["y",1710],"(",["y",0],")"]],[-92551,["グレゴリオ暦享保",["y",1715],"(",["y",0],")"]],[-85309,["グレゴリオ暦元文",["y",1735],"(",["y",0],")"]],[-83539,["グレゴリオ暦寛保",["y",1740],"(",["y",0],")"]],[-82452,["グレゴリオ暦延享",["y",1743],"(",["y",0],")"]],[-80867,["グレゴリオ暦寛延",["y",1747],"(",["y",0],")"]],[-79641,["グレゴリオ暦宝暦",["y",1750],"(",["y",0],")"]],[-75059,["グレゴリオ暦明和",["y",1763],"(",["y",0],")"]],[-71974,["グレゴリオ暦安永",["y",1771],"(",["y",0],")"]],[-68916,["グレゴリオ暦天明",["y",1780],"(",["y",0],")"]],[-66059,["グレゴリオ暦寛政",["y",1788],"(",["y",0],")"]],[-61649,["グレゴリオ暦享和",["y",1800],"(",["y",0],")"]],[-60550,["グレゴリオ暦文化",["y",1803],"(",["y",0],")"]],[-55372,["グレゴリオ暦文政",["y",1817],"(",["y",0],")"]],[-50747,["グレゴリオ暦天保",["y",1829],"(",["y",0],")"]],[-45647,["グレゴリオ暦弘化",["y",1843],"(",["y",0],")"]],[-44469,["グレゴリオ暦嘉永",["y",1847],"(",["y",0],")"]],[-41989,["グレゴリオ暦安政",["y",1853],"(",["y",0],")"]],[-40079,["グレゴリオ暦万延",["y",1859],"(",["y",0],")"]],[-39724,["グレゴリオ暦文久",["y",1860],"(",["y",0],")"]],[-38630,["グレゴリオ暦元治",["y",1863],"(",["y",0],")"]],[-38230,["グレゴリオ暦慶応",["y",1864],"(",["y",0],")"]],[-36959,["グレゴリオ暦M",["y",1867],"(",["y",0],")"]],[-35428,["M",["y",1867],"(",["y",0],")"]],[-20974,["T",["y",1911],"(",["y",0],")"]],[-15713,["S",["y",1925],"(",["y",0],")"]],[6947,["H",["y",1988],"(",["y",0],")"]],[18017,["R",["y",2018],"(",["y",0],")"]]],"dtsjp3":[[null,["グレゴリオ暦",["y",0]]],[-962750,["グレゴリオ暦",["y",0],"(神武天皇即位前",["k"],")"]],[-960181,["グレゴリオ暦",["y",0],"(神武",["y",-660],")"]],[-931329,["グレゴリオ暦",["y",0],"(綏靖",["y",-581],")"]],[-919281,["グレゴリオ暦",["y",0],"(安寧",["y",-548],")"]],[-905401,["グレゴリオ暦",["y",0],"(懿徳",["y",-510],")"]],[-892615,["グレゴリオ暦",["y",0],"(孝昭",["y",-475],")"]],[-862316,["グレゴリオ暦",["y",0],"(孝安",["y",-392],")"]],[-825049,["グレゴリオ暦",["y",0],"(孝霊",["y",-290],")"]],[-797290,["グレゴリオ暦",["y",0],"(孝元",["y",-214],")"]],[-776471,["グレゴリオ暦",["y",0],"(開化",["y",-157],")"]],[-754559,["グレゴリオ暦",["y",0],"(崇神",["y",-97],")"]],[-729724,["グレゴリオ暦",["y",0],"(垂仁",["y",-29],")"]],[-693549,["グレゴリオ暦",["y",0],"(景行",["y",70],")"]],[-671637,["グレゴリオ暦",["y",0],"(成務",["y",130],")"]],[-649371,["グレゴリオ暦",["y",0],"(仲哀",["y",191],")"]],[-646093,["グレゴリオ暦",["y",0],"(神功",["y",200],")"]],[-620874,["グレゴリオ暦",["y",0],"(応神",["y",269],")"]],[-605164,["グレゴリオ暦",["y",0],"(仁徳",["y",312],")"]],[-573389,["グレゴリオ暦",["y",0],"(履中",["y",399],")"]],[-571204,["グレゴリオ暦",["y",0],"(反正",["y",405],")"]],[-569018,["グレゴリオ暦",["y",0],"(允恭",["y",411],")"]],[-553662,["グレゴリオ暦",["y",0],"(安康",["y",453],")"]],[-552570,["グレゴリオ暦",["y",0],"(雄略",["y",456],")"]],[-544183,["グレゴリオ暦",["y",0],"(清寧",["y",479],")"]],[-542352,["グレゴリオ暦",["y",0],"(顕宗",["y",484],")"]],[-541260,["グレゴリオ暦",["y",0],"(仁賢",["y",487],")"]],[-537243,["グレゴリオ暦",["y",0],"(武烈",["y",498],")"]],[-534320,["グレゴリオ暦",["y",0],"(継体",["y",506],")"]],[-524457,["グレゴリオ暦",["y",0],"(安閑",["y",533],")"]],[-523718,["グレゴリオ暦",["y",0],"(宣化",["y",535],")"]],[-522271,["グレゴリオ暦",["y",0],"(欽明",["y",539],")"]],[-510577,["グレゴリオ暦",["y",0],"(敏達",["y",571],")"]],[-505469,["グレゴリオ暦",["y",0],"(用明",["y",585],")"]],[-504730,["グレゴリオ暦",["y",0],"(崇峻",["y",587],")"]],[-502899,["グレゴリオ暦",["y",0],"(推古",["y",592],")"]],[-489758,["グレゴリオ暦",["y",0],"(舒明",["y",628],")"]],[-485004,["グレゴリオ暦",["y",0],"(皇極",["y",641],")"]],[-483746,["グレゴリオ暦",["y",0],"(大化",["y",644],")"]],[-482037,["グレゴリオ暦",["y",0],"(白雉",["y",649],")"]],[-480249,["グレゴリオ暦",["y",0],"(斉明",["y",654],")"]],[-477710,["グレゴリオ暦",["y",0],"(天智",["y",661],")"]],[-474048,["グレゴリオ暦",["y",0],"(天武",["y",671],")"]],[-468743,["グレゴリオ暦",["y",0],"(朱鳥",["y",685],")"]],[-468555,["グレゴリオ暦",["y",0],"(持統",["y",686],")"]],[-464717,["グレゴリオ暦",["y",0],"(文武",["y",696],")"]],[-463367,["グレゴリオ暦",["y",0],"(大宝",["y",700],")"]],[-462227,["グレゴリオ暦",["y",0],"(慶雲",["y",703],")"]],[-460896,["グレゴリオ暦",["y",0],"(和銅",["y",707],")"]],[-458101,["グレゴリオ暦",["y",0],"(霊亀",["y",714],")"]],[-457288,["グレゴリオ暦",["y",0],"(養老",["y",716],")"]],[-455027,["グレゴリオ暦",["y",0],"(神亀",["y",723],")"]],[-453018,["グレゴリオ暦",["y",0],"(天平",["y",728],")"]],[-445834,["グレゴリオ暦",["y",0],"(天平感宝",["y",748],")"]],[-445727,["グレゴリオ暦",["y",0],"(天平勝宝",["y",748],")"]],[-442787,["グレゴリオ暦",["y",0],"(天平宝字",["y",756],")"]],[-440082,["グレゴリオ暦",["y",0],"(天平神護",["y",764],")"]],[-439128,["グレゴリオ暦",["y",0],"(神護景雲",["y",766],")"]],[-437992,["グレゴリオ暦",["y",0],"(宝亀",["y",769],")"]],[-434240,["グレゴリオ暦",["y",0],"(天応",["y",780],")"]],[-433632,["グレゴリオ暦",["y",0],"(延暦",["y",781],")"]],[-424980,["グレゴリオ暦",["y",0],"(大同",["y",805],")"]],[-423385,["グレゴリオ暦",["y",0],"(弘仁",["y",809],")"]],[-418526,["グレゴリオ暦",["y",0],"(天長",["y",823],")"]],[-414867,["グレゴリオ暦",["y",0],"(承和",["y",833],")"]],[-409601,["グレゴリオ暦",["y",0],"(嘉祥",["y",847],")"]],[-408551,["グレゴリオ暦",["y",0],"(仁寿",["y",850],")"]],[-407250,["グレゴリオ暦",["y",0],"(斉衡",["y",853],")"]],[-406432,["グレゴリオ暦",["y",0],"(天安",["y",856],")"]],[-405641,["グレゴリオ暦",["y",0],"(貞観",["y",858],")"]],[-399054,["グレゴリオ暦",["y",0],"(元慶",["y",876],")"]],[-396214,["グレゴリオ暦",["y",0],"(仁和",["y",884],")"]],[-394673,["グレゴリオ暦",["y",0],"(寛平",["y",888],")"]],[-391396,["グレゴリオ暦",["y",0],"(昌泰",["y",897],")"]],[-390197,["グレゴリオ暦",["y",0],"(延喜",["y",900],")"]],[-382256,["グレゴリオ暦",["y",0],"(延長",["y",922],")"]],[-379347,["グレゴリオ暦",["y",0],"(承平",["y",930],")"]],[-376753,["グレゴリオ暦",["y",0],"(天慶",["y",937],")"]],[-373504,["グレゴリオ暦",["y",0],"(天暦",["y",946],")"]],[-369661,["グレゴリオ暦",["y",0],"(天徳",["y",956],")"]],[-368461,["グレゴリオ暦",["y",0],"(応和",["y",960],")"]],[-367198,["グレゴリオ暦",["y",0],"(康保",["y",963],")"]],[-365717,["グレゴリオ暦",["y",0],"(安和",["y",967],")"]],[-365115,["グレゴリオ暦",["y",0],"(天禄",["y",969],")"]],[-363761,["グレゴリオ暦",["y",0],"(天延",["y",972],")"]],[-362823,["グレゴリオ暦",["y",0],"(貞元",["y",975],")"]],[-361951,["グレゴリオ暦",["y",0],"(天元",["y",977],")"]],[-360341,["グレゴリオ暦",["y",0],"(永観",["y",982],")"]],[-359620,["グレゴリオ暦",["y",0],"(寛和",["y",984],")"]],[-358904,["グレゴリオ暦",["y",0],"(永延",["y",986],")"]],[-358045,["グレゴリオ暦",["y",0],"(永祚",["y",988],")"]],[-357603,["グレゴリオ暦",["y",0],"(正暦",["y",989],")"]],[-356023,["グレゴリオ暦",["y",0],"(長徳",["y",994],")"]],[-354614,["グレゴリオ暦",["y",0],"(長保",["y",998],")"]],[-352599,["グレゴリオ暦",["y",0],"(寛弘",["y",1003],")"]],[-349493,["グレゴリオ暦",["y",0],"(長和",["y",1011],")"]],[-347930,["グレゴリオ暦",["y",0],"(寛仁",["y",1016],")"]],[-346534,["グレゴリオ暦",["y",0],"(治安",["y",1020],")"]],[-345283,["グレゴリオ暦",["y",0],"(万寿",["y",1023],")"]],[-343823,["グレゴリオ暦",["y",0],"(長元",["y",1027],")"]],[-340637,["グレゴリオ暦",["y",0],"(長暦",["y",1036],")"]],[-339320,["グレゴリオ暦",["y",0],"(長久",["y",1039],")"]],[-337859,["グレゴリオ暦",["y",0],"(寛徳",["y",1043],")"]],[-337337,["グレゴリオ暦",["y",0],"(永承",["y",1045],")"]],[-334889,["グレゴリオ暦",["y",0],"(天喜",["y",1052],")"]],[-332834,["グレゴリオ暦",["y",0],"(康平",["y",1057],")"]],[-330292,["グレゴリオ暦",["y",0],"(治暦",["y",1064],")"]],[-328952,["グレゴリオ暦",["y",0],"(延久",["y",1068],")"]],[-326993,["グレゴリオ暦",["y",0],"(承保",["y",1073],")"]],[-325817,["グレゴリオ暦",["y",0],"(承暦",["y",1076],")"]],[-324614,["グレゴリオ暦",["y",0],"(永保",["y",1080],")"]],[-323525,["グレゴリオ暦",["y",0],"(応徳",["y",1083],")"]],[-322373,["グレゴリオ暦",["y",0],"(寛治",["y",1086],")"]],[-319559,["グレゴリオ暦",["y",0],"(嘉保",["y",1093],")"]],[-318848,["グレゴリオ暦",["y",0],"(永長",["y",1095],")"]],[-318490,["グレゴリオ暦",["y",0],"(承徳",["y",1096],")"]],[-317863,["グレゴリオ暦",["y",0],"(康和",["y",1098],")"]],[-316227,["グレゴリオ暦",["y",0],"(長治",["y",1103],")"]],[-315431,["グレゴリオ暦",["y",0],"(嘉承",["y",1105],")"]],[-314581,["グレゴリオ暦",["y",0],"(天仁",["y",1107],")"]],[-313891,["グレゴリオ暦",["y",0],"(天永",["y",1109],")"]],[-312770,["グレゴリオ暦",["y",0],"(永久",["y",1112],")"]],[-311066,["グレゴリオ暦",["y",0],"(元永",["y",1117],")"]],[-310321,["グレゴリオ暦",["y",0],"(保安",["y",1119],")"]],[-308851,["グレゴリオ暦",["y",0],"(天治",["y",1123],")"]],[-308213,["グレゴリオ暦",["y",0],"(大治",["y",1125],")"]],[-306374,["グレゴリオ暦",["y",0],"(天承",["y",1130],")"]],[-305803,["グレゴリオ暦",["y",0],"(長承",["y",1131],")"]],[-304811,["グレゴリオ暦",["y",0],"(保延",["y",1134],")"]],[-302555,["グレゴリオ暦",["y",0],"(永治",["y",1140],")"]],[-302270,["グレゴリオ暦",["y",0],"(康治",["y",1141],")"]],[-301597,["グレゴリオ暦",["y",0],"(天養",["y",1143],")"]],[-301095,["グレゴリオ暦",["y",0],"(久安",["y",1144],")"]],[-299083,["グレゴリオ暦",["y",0],"(仁平",["y",1150],")"]],[-297694,["グレゴリオ暦",["y",0],"(久寿",["y",1153],")"]],[-297163,["グレゴリオ暦",["y",0],"(保元",["y",1155],")"]],[-296077,["グレゴリオ暦",["y",0],"(平治",["y",1158],")"]],[-295792,["グレゴリオ暦",["y",0],"(永暦",["y",1159],")"]],[-295208,["グレゴリオ暦",["y",0],"(応保",["y",1160],")"]],[-294621,["グレゴリオ暦",["y",0],"(長寛",["y",1162],")"]],[-293819,["グレゴリオ暦",["y",0],"(永万",["y",1164],")"]],[-293383,["グレゴリオ暦",["y",0],"(仁安",["y",1165],")"]],[-292427,["グレゴリオ暦",["y",0],"(嘉応",["y",1168],")"]],[-291676,["グレゴリオ暦",["y",0],"(承安",["y",1170],")"]],[-290134,["グレゴリオ暦",["y",0],"(安元",["y",1174],")"]],[-289390,["グレゴリオ暦",["y",0],"(治承",["y",1176],")"]],[-287933,["グレゴリオ暦",["y",0],"(養和",["y",1180],")"]],[-287625,["グレゴリオ暦",["y",0],"(寿永",["y",1181],")"]],[-286927,["グレゴリオ暦",["y",0],"(元暦",["y",1183],")"]],[-286457,["グレゴリオ暦",["y",0],"(文治",["y",1184],")"]],[-284747,["グレゴリオ暦",["y",0],"(建久",["y",1189],")"]],[-281453,["グレゴリオ暦",["y",0],"(正治",["y",1198],")"]],[-280787,["グレゴリオ暦",["y",0],"(建仁",["y",1200],")"]],[-279687,["グレゴリオ暦",["y",0],"(元久",["y",1203],")"]],[-278883,["グレゴリオ暦",["y",0],"(建永",["y",1205],")"]],[-278354,["グレゴリオ暦",["y",0],"(承元",["y",1206],")"]],[-277100,["グレゴリオ暦",["y",0],"(建暦",["y",1210],")"]],[-276099,["グレゴリオ暦",["y",0],"(建保",["y",1212],")"]],[-274144,["グレゴリオ暦",["y",0],"(承久",["y",1218],")"]],[-273050,["グレゴリオ暦",["y",0],"(貞応",["y",1221],")"]],[-272099,["グレゴリオ暦",["y",0],"(元仁",["y",1223],")"]],[-271951,["グレゴリオ暦",["y",0],"(嘉禄",["y",1224],")"]],[-270986,["グレゴリオ暦",["y",0],"(安貞",["y",1226],")"]],[-270548,["グレゴリオ暦",["y",0],"(寛喜",["y",1228],")"]],[-269429,["グレゴリオ暦",["y",0],"(貞永",["y",1231],")"]],[-269032,["グレゴリオ暦",["y",0],"(天福",["y",1232],")"]],[-268481,["グレゴリオ暦",["y",0],"(文暦",["y",1233],")"]],[-268142,["グレゴリオ暦",["y",0],"(嘉禎",["y",1234],")"]],[-266987,["グレゴリオ暦",["y",0],"(暦仁",["y",1237],")"]],[-266914,["グレゴリオ暦",["y",0],"(延応",["y",1238],")"]],[-266403,["グレゴリオ暦",["y",0],"(仁治",["y",1239],")"]],[-265448,["グレゴリオ暦",["y",0],"(寛元",["y",1242],")"]],[-263969,["グレゴリオ暦",["y",0],"(宝治",["y",1246],")"]],[-263211,["グレゴリオ暦",["y",0],"(建長",["y",1248],")"]],[-260479,["グレゴリオ暦",["y",0],"(康元",["y",1255],")"]],[-260321,["グレゴリオ暦",["y",0],"(正嘉",["y",1256],")"]],[-259571,["グレゴリオ暦",["y",0],"(正元",["y",1258],")"]],[-259171,["グレゴリオ暦",["y",0],"(文応",["y",1259],")"]],[-258869,["グレゴリオ暦",["y",0],"(弘長",["y",1260],")"]],[-257768,["グレゴリオ暦",["y",0],"(文永",["y",1263],")"]],[-253695,["グレゴリオ暦",["y",0],"(建治",["y",1274],")"]],[-252659,["グレゴリオ暦",["y",0],"(弘安",["y",1277],")"]],[-248939,["グレゴリオ暦",["y",0],"(正応",["y",1287],")"]],[-247013,["グレゴリオ暦",["y",0],"(永仁",["y",1292],")"]],[-244926,["グレゴリオ暦",["y",0],"(正安",["y",1298],")"]],[-243631,["グレゴリオ暦",["y",0],"(乾元",["y",1301],")"]],[-243351,["グレゴリオ暦",["y",0],"(嘉元",["y",1302],")"]],[-242131,["グレゴリオ暦",["y",0],"(徳治",["y",1305],")"]],[-241457,["グレゴリオ暦",["y",0],"(延慶",["y",1307],")"]],[-240551,["グレゴリオ暦",["y",0],"(応長",["y",1310],")"]],[-240205,["グレゴリオ暦",["y",0],"(正和",["y",1311],")"]],[-238421,["グレゴリオ暦",["y",0],"(文保",["y",1316],")"]],[-237628,["グレゴリオ暦",["y",0],"(元応",["y",1318],")"]],[-236954,["グレゴリオ暦",["y",0],"(元亨",["y",1320],")"]],[-235580,["グレゴリオ暦",["y",0],"(正中",["y",1323],")"]],[-235061,["グレゴリオ暦",["y",0],"(嘉暦",["y",1325],")"]],[-233848,["グレゴリオ暦",["y",0],"(元徳",["y",1328],")"]],[-233129,["グレゴリオ暦",["y",0],"(元弘",["y",1330],"/元徳",["y",1328],")"]],[-232874,["グレゴリオ暦",["y",0],"(元弘",["y",1330],"/正慶",["y",1331],")"]],[-232464,["グレゴリオ暦",["y",0],"(元弘",["y",1330],")"]],[-232223,["グレゴリオ暦",["y",0],"(建武",["y",1333],")"]],[-231455,["グレゴリオ暦",["y",0],"(延元",["y",1335],")"]],[-231352,["グレゴリオ暦",["y",0],"(延元",["y",1335],"/建武",["y",1333],")"]],[-230542,["グレゴリオ暦",["y",0],"(延元",["y",1335],"/暦応",["y",1337],")"]],[-229950,["グレゴリオ暦",["y",0],"(興国",["y",1339],"/暦応",["y",1337],")"]],[-229213,["グレゴリオ暦",["y",0],"(興国",["y",1339],"/康永",["y",1341],")"]],[-227950,["グレゴリオ暦",["y",0],"(興国",["y",1339],"/貞和",["y",1344],")"]],[-227519,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/貞和",["y",1344],")"]],[-226349,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/観応",["y",1349],")"]],[-225748,["グレゴリオ暦",["y",0],"(正平",["y",1345],")"]],[-225593,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/観応",["y",1349],")"]],[-225404,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/文和",["y",1351],")"]],[-224132,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/延文",["y",1355],")"]],[-222301,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/康安",["y",1360],")"]],[-221776,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/貞治",["y",1361],")"]],[-219802,["グレゴリオ暦",["y",0],"(正平",["y",1345],"/応安",["y",1367],")"]],[-219076,["グレゴリオ暦",["y",0],"(建徳",["y",1369],"/応安",["y",1367],")"]],[-218256,["グレゴリオ暦",["y",0],"(文中",["y",1371],"/応安",["y",1367],")"]],[-217224,["グレゴリオ暦",["y",0],"(文中",["y",1371],"/永和",["y",1374],")"]],[-217135,["グレゴリオ暦",["y",0],"(天授",["y",1374],"/永和",["y",1374],")"]],[-215752,["グレゴリオ暦",["y",0],"(天授",["y",1374],"/康暦",["y",1378],")"]],[-215055,["グレゴリオ暦",["y",0],"(弘和",["y",1380],"/康暦",["y",1378],")"]],[-215041,["グレゴリオ暦",["y",0],"(弘和",["y",1380],"/永徳",["y",1380],")"]],[-213946,["グレゴリオ暦",["y",0],"(弘和",["y",1380],"/至徳",["y",1383],")"]],[-213886,["グレゴリオ暦",["y",0],"(元中",["y",1383],"/至徳",["y",1383],")"]],[-212651,["グレゴリオ暦",["y",0],"(元中",["y",1383],"/嘉慶",["y",1386],")"]],[-212132,["グレゴリオ暦",["y",0],"(元中",["y",1383],"/康応",["y",1388],")"]],[-211731,["グレゴリオ暦",["y",0],"(元中",["y",1383],"/明徳",["y",1389],")"]],[-210779,["グレゴリオ暦",["y",0],"(明徳",["y",1389],")"]],[-210158,["グレゴリオ暦",["y",0],"(応永",["y",1393],")"]],[-197792,["グレゴリオ暦",["y",0],"(正長",["y",1427],")"]],[-197312,["グレゴリオ暦",["y",0],"(永享",["y",1428],")"]],[-193136,["グレゴリオ暦",["y",0],"(嘉吉",["y",1440],")"]],[-192056,["グレゴリオ暦",["y",0],"(文安",["y",1443],")"]],[-190055,["グレゴリオ暦",["y",0],"(宝徳",["y",1448],")"]],[-188965,["グレゴリオ暦",["y",0],"(享徳",["y",1451],")"]],[-187843,["グレゴリオ暦",["y",0],"(康正",["y",1454],")"]],[-187072,["グレゴリオ暦",["y",0],"(長禄",["y",1456],")"]],[-185868,["グレゴリオ暦",["y",0],"(寛正",["y",1459],")"]],[-184001,["グレゴリオ暦",["y",0],"(文正",["y",1465],")"]],[-183610,["グレゴリオ暦",["y",0],"(応仁",["y",1466],")"]],[-182819,["グレゴリオ暦",["y",0],"(文明",["y",1468],")"]],[-176183,["グレゴリオ暦",["y",0],"(長享",["y",1486],")"]],[-175414,["グレゴリオ暦",["y",0],"(延徳",["y",1488],")"]],[-174353,["グレゴリオ暦",["y",0],"(明応",["y",1491],")"]],[-171213,["グレゴリオ暦",["y",0],"(文亀",["y",1500],")"]],[-170119,["グレゴリオ暦",["y",0],"(永正",["y",1503],")"]],[-163719,["グレゴリオ暦",["y",0],"(大永",["y",1520],")"]],[-161182,["グレゴリオ暦",["y",0],"(享禄",["y",1527],")"]],[-159726,["グレゴリオ暦",["y",0],"(天文",["y",1531],")"]],[-151256,["グレゴリオ暦",["y",0],"(弘治",["y",1554],")"]],[-150394,["グレゴリオ暦",["y",0],"(永禄",["y",1557],")"]],[-145941,["グレゴリオ暦",["y",0],"(元亀",["y",1569],")"]],[-144755,["グレゴリオ暦",["y",0],"(天正",["y",1572],")"]],[-137687,["グレゴリオ暦",["y",0],"(文禄",["y",1591],")"]],[-136251,["グレゴリオ暦",["y",0],"(慶長",["y",1595],")"]],[-129414,["グレゴリオ暦",["y",0],"(元和",["y",1614],")"]],[-126267,["グレゴリオ暦",["y",0],"(寛永",["y",1623],")"]],[-118691,["グレゴリオ暦",["y",0],"(正保",["y",1643],")"]],[-117511,["グレゴリオ暦",["y",0],"(慶安",["y",1647],")"]],[-115854,["グレゴリオ暦",["y",0],"(承応",["y",1651],")"]],[-114914,["グレゴリオ暦",["y",0],"(明暦",["y",1654],")"]],[-113723,["グレゴリオ暦",["y",0],"(万治",["y",1657],")"]],[-112717,["グレゴリオ暦",["y",0],"(寛文",["y",1660],")"]],[-108174,["グレゴリオ暦",["y",0],"(延宝",["y",1672],")"]],[-105242,["グレゴリオ暦",["y",0],"(天和",["y",1680],")"]],[-104364,["グレゴリオ暦",["y",0],"(貞享",["y",1683],")"]],[-102702,["グレゴリオ暦",["y",0],"(元禄",["y",1687],")"]],[-97049,["グレゴリオ暦",["y",0],"(宝永",["y",1703],")"]],[-94437,["グレゴリオ暦",["y",0],"(正徳",["y",1710],")"]],[-92551,["グレゴリオ暦",["y",0],"(享保",["y",1715],")"]],[-85309,["グレゴリオ暦",["y",0],"(元文",["y",1735],")"]],[-83539,["グレゴリオ暦",["y",0],"(寛保",["y",1740],")"]],[-82452,["グレゴリオ暦",["y",0],"(延享",["y",1743],")"]],[-80867,["グレゴリオ暦",["y",0],"(寛延",["y",1747],")"]],[-79641,["グレゴリオ暦",["y",0],"(宝暦",["y",1750],")"]],[-75059,["グレゴリオ暦",["y",0],"(明和",["y",1763],")"]],[-71974,["グレゴリオ暦",["y",0],"(安永",["y",1771],")"]],[-68916,["グレゴリオ暦",["y",0],"(天明",["y",1780],")"]],[-66059,["グレゴリオ暦",["y",0],"(寛政",["y",1788],")"]],[-61649,["グレゴリオ暦",["y",0],"(享和",["y",1800],")"]],[-60550,["グレゴリオ暦",["y",0],"(文化",["y",1803],")"]],[-55372,["グレゴリオ暦",["y",0],"(文政",["y",1817],")"]],[-50747,["グレゴリオ暦",["y",0],"(天保",["y",1829],")"]],[-45647,["グレゴリオ暦",["y",0],"(弘化",["y",1843],")"]],[-44469,["グレゴリオ暦",["y",0],"(嘉永",["y",1847],")"]],[-41989,["グレゴリオ暦",["y",0],"(安政",["y",1853],")"]],[-40079,["グレゴリオ暦",["y",0],"(万延",["y",1859],")"]],[-39724,["グレゴリオ暦",["y",0],"(文久",["y",1860],")"]],[-38630,["グレゴリオ暦",["y",0],"(元治",["y",1863],")"]],[-38230,["グレゴリオ暦",["y",0],"(慶応",["y",1864],")"]],[-36959,["グレゴリオ暦",["y",0],"(M",["y",1867],")"]],[-35428,["",["y",0],"(M",["y",1867],")"]],[-20974,["",["y",0],"(T",["y",1911],")"]],[-15713,["",["y",0],"(S",["y",1925],")"]],[6947,["",["y",0],"(H",["y",1988],")"]],[18017,["",["y",0],"(R",["y",2018],")"]]]}};/*
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
function observerAngle(height) { return -2.076 * Math.sqrt(height) / 60; }

// returns set time for the given sun altitude
function getSetJ(h, lw, phi, dec, n, M, L) {

    var w = hourAngle(h, phi, dec),
        a = approxTransit(w, lw, n);
    return solarTransitJ(a, M, L);
}


// calculates sun times for a given date, latitude/longitude, and, optionally,
// the observer height (in meters) relative to the horizon

SunCalc.getTimes = function (date, lat, lng, height) {

    height = height || 0;

    var lw = rad * -lng,
        phi = rad * lat,

        dh = observerAngle(height),

        d = toDays(date),
        n = julianCycle(d, lw),
        ds = approxTransit(0, lw, n),

        M = solarMeanAnomaly(ds),
        L = eclipticLongitude(M),
        dec = declination(L, 0),

        Jnoon = solarTransitJ(ds, M, L),

        i, len, time, h0, Jset, Jrise;


    var result = {
        solarNoon: fromJulian(Jnoon),
        nadir: fromJulian(Jnoon - 0.5)
    };

    for (i = 0, len = times.length; i < len; i += 1) {
        time = times[i];
        h0 = (time[0] + dh) * rad;

        Jset = getSetJ(h0, lw, phi, dec, n, M, L);
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
