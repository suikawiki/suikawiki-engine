function TER (c) {
  this.container = c;
  this._initialize ();
} // TER

/* Based on HTML5 "global date and time string", but allows
Unicode 5.1.0 White_Space where it was allowed in earlier draft of HTML5. */
TER.globalDateAndTimeStringPattern = /^([0-9]{4,})-([0-9]{2})-([0-9]{2})(?:[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+(?:T[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*)?|T[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*)([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.([0-9]+))?)?[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]*(?:Z|([+-])([0-9]{2}):([0-9]{2}))$/;

/* HTML5 "date string" */
TER.dateStringPattern = /^([0-9]{4,})-([0-9]{2})-([0-9]{2})$/;

/* HTML5 "time string" */
TER.timeStringPattern = /^([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\.([0-9]+))?)?$/;

TER.prototype._initialize = function () {
  var els = this.container.getElementsByTagName ('time');
  var elsL = els.length;
  for (var i = 0; i < elsL; i++) {
    var el = els[i];
    if (!el) break; /* If <time> is nested */
    this._replaceTimeContent (el);
  }
}; // TER.prototype._initialize

TER.prototype._replaceTimeContent = function (el) {
  var date = this._getDate (el);
  if (isNaN (date.valueOf ())) return;
  if (date.hasTimezone) { /* full date */
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent || this._getTextContent (el));
    }
    if (!el.getAttribute ('datetime')) {
      this._setDateTimeAttr (el, date);
    }
    this._setDateTimeContent (el, date);
  } else if (date.hasDate) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent || this._getTextContent (el));
    }
    if (!el.getAttribute ('datetime')) {
      this._setDateAttr (el, date);
    }
    this._setDateContent (el, date);
  } else if (date.hasTime) {
    if (!el.getAttribute ('title')) {
      el.setAttribute ('title', el.textContent || this._getTextContent (el));
    }
    if (!el.getAttribute ('datetime')) {
      this._setTimeAttr (el, date);
    }
    this._setTimeContent (el, date);
  }
}; // TER.prototype._replaceTimeContent

TER.prototype._setDateTimeContent = function (el, date) {
  this._setTextContent (el, date.toLocaleString ());
}; // TER.prototype._setDateTimeContent

TER.prototype._setDateContent = function (el, date) {
  this._setTextContent (el, this._getLocal (date).toLocaleDateString ());
}; // TER.prototype._setDateContent

TER.prototype._setTimeContent = function (el, date) {
  this._setTextContent (el, this._getLocal (date).toLocaleTimeString ());
}; // TER.prototype._setTimeContent

TER.prototype._setDateTimeAttr = function (el, date) {
  var r = '';
  r = date.getUTCFullYear (); // JS does not support years 0001-0999
  r += '-' + ('0' + (date.getUTCMonth () + 1)).slice (-2);
  r += '-' + ('0' + date.getUTCDate ()).slice (-2);
  r += 'T' + ('0' + date.getUTCHours ()).slice (-2);
  r += ':' + ('0' + date.getUTCMinutes ()).slice (-2);
  r += ':' + ('0' + date.getUTCSeconds ()).slice (-2);
  r += '.' + (date.getUTCMilliseconds () + '00').slice (2);
  r += 'Z';
  el.setAttribute ('datetime', r);
}; // TER.prototype._setDateTimeAttr

TER.prototype._setDateAttr = function (el, date) {
  var r = '';
  r = date.getUTCFullYear (); // JS does not support years 0001-0999
  r += '-' + ('0' + (date.getUTCMonth () + 1)).slice (-2);
  r += '-' + ('0' + date.getUTCDate ()).slice (-2);
  el.setAttribute ('datetime', r);
}; // TER.prototype._setDateAttr

TER.prototype._setTimeAttr = function (el, date) {
  var r = '';
  r = ('0' + date.getUTCHours ()).slice (-2);
  r += ':' + ('0' + date.getUTCMinutes ()).slice (-2);
  r += ':' + ('0' + date.getUTCSeconds ()).slice (-2);
  r += '.' + (date.getUTCMilliseconds () + '00').slice (2);
  el.setAttribute ('datetime', r);
}; // TER.prototype._setTimeAttr

TER.prototype._getLocal = function (d) {
  /* Return a Date with same numbers of date/time, but in local timezone */
  return new Date (d.getUTCFullYear (), d.getUTCMonth (), d.getUTCDate (),
      d.getUTCHours (), d.getUTCMinutes (), d.getUTCSeconds (),
      d.getUTCMilliseconds ());
}; // TER.prototype._getLocal

TER.prototype._getDate = function (el) {
  var datetime = el.getAttribute ('datetime');
  if (datetime) { /* NOTE: IE7 does not have hasAttribute */
    datetime = el.getAttribute ('datetime');
  } else {
    datetime = el.textContent || this._getTextContent (el);
    datetime = this._trimWhiteSpace (datetime);
  }

  if (m = datetime.match (TER.globalDateAndTimeStringPattern)) {
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
  } else if (m = datetime.match (TER.dateStringPattern)) {
    if (m[1] < 100) {
      return new Date (NaN);
    }
    var d = new Date (Date.UTC (m[1], m[2] - 1, m[3], 0, 0, 0));
    if (m[1] != d.getUTCFullYear () ||
        m[2] != d.getUTCMonth () + 1 ||
        m[3] != d.getUTCDate ()) {
      return new Date (NaN); // bad date error.
    }
    d.hasDate = true;
    return d;
  } else if (m = datetime.match (TER.timeStringPattern)) {
    var d = new Date (Date.UTC (1970, 1 - 1, 1, m[1], m[2], m[3] || 0));
    if (m[1] != d.getUTCHours () ||
        m[2] != d.getUTCMinutes () ||
        (m[3] || 0) != d.getUTCSeconds ()) {
      return new Date (NaN); // bad time error.
    }
    if (m[4]) {
      var ms = (m[4] + "000").substring (0, 3);
      d.setMilliseconds (ms);
    }
    d.hasTime = true;
    return d;
  } else {
    return new Date (NaN);
  }
}; // TER.prototype._getDate

TER.prototype._getTextContent = function (el) {
  var r = '';
  var elC = el.childNodes;
  var elCL = elC.length;
  for (var i = 0; i < elCL; i++) {
    var child = elC[i];
    if (child.nodeType == 3 || child.nodeType == 4) {
      r += child.data;
    } else if (child.nodeType == 1) {
      r += this._getTextContent (child);
    }
  }
  return r;
}; // TER.prototype._getTextContent

TER.prototype._setTextContent = function (el, s) {
  el.innerText = s;
  el.textContent = s;
}; // TER.prototype._setTextContent

TER.prototype._trimWhiteSpace = function (s) {
  /* Unicode 5.1.0 White_Space */
  return s.replace
      (/^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/, '')
      .replace
      (/[\u0009-\u000D\u0020\u0085\u00A0\u1680\u180E\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+$/, '');
}; // TER.prototype._trimWhiteSpace

TER.Delta = function (c) {
  TER.apply (this, [c]);
}; // TER.Delta

/* Don't delete createElement('time') - this is a hack to support IE */
TER.Delta.prototype = new TER (document.createElement ('time'));

TER.Delta.prototype._setDateTimeContent = function (el, date) {
  var dateValue = date.valueOf ();
  var nowValue = new Date ().valueOf ();

  var diff = dateValue - nowValue;
  if (diff < 0) diff = -diff;

  if (diff == 0) {
    this._setTextContent (el, this.text.now ());
    return;
  }

  var v;
  diff = Math.floor (diff / 1000);
  if (diff < 60) {
    v = this.text.second (diff);
  } else {
    var f = diff;
    diff = Math.floor (diff / 60);
    if (diff < 60) {
      v = this.text.minute (diff);
      f -= diff * 60;
      if (f > 0) v += this.text.sep () + this.text.second (f);
    } else {
      f = diff;
      diff = Math.floor (diff / 60);
      if (diff < 50) {
        v = this.text.hour (diff);
        f -= diff * 60;
        if (f > 0) v += this.text.sep () + this.text.minute (f);
      } else {
        f = diff;
        diff = Math.floor (diff / 24);
        if (diff < 100) {
          v = this.text.day (diff);
          f -= diff * 24;
          if (f > 0) v += this.text.sep () + this.text.hour (f);
        } else {
          this._setTextContent (el, date.toLocaleString ());
          return;
        }
      }
    }
  }

  if (dateValue < nowValue) {
    v = this.text.before (v);
  } else {
    v = this.text.after (v);
  }
  this._setTextContent (el, v);
}; // TER.Delta.prototype._setDateTimeContent

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
  var lang = navigator.browserLanguage || navigator.language || navigator.userLanguage || '';
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

  <script>
    window.onload = function () {
      new TER (document.body);
    };
  </script>
  <script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script>
  
  <time>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered appropriately in the user's locale -->

... or:

  <script>
    window.onload = function () {
      new TER.Delta (document.body);
    };
  </script>
  <script src="http://suika.fam.cx/www/style/ui/time.js.u8" charset=utf-8></script>
  
  <time>2008-12-20T23:27+09:00</time>
  <!-- Will be rendered like "2 minutes ago" in English or Japanese -->

If you'd like to load this script AFTER |time| elements are parsed,
invoke |document.createElement ('time')| before they are used,
otherwise they cannot be parsed appropriately in WinIE.

Latest version of this script is available at
<http://suika.fam.cx/www/style/ui/time.js.u8>.  Old versions of this
script are available from
<http://suika.fam.cx/www/style/ui/time.js.u8,cvslog>.

This script supports the HTML |time| element, which is a willful
violation to the HTML Living Standard as of October 30, 2011.

This script interprets "global date and time string" using older
parsing rules as defined in previous versions of the HTML spec, which
is a willful violation to the current HTML Living Standard.

*/

/* ***** BEGIN LICENSE BLOCK *****
 * Copyright 2008-2015 Wakaba <wakaba@suikawiki.org>.  All rights reserved.
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
 * <http://www.mozilla.org/MPL/>
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
