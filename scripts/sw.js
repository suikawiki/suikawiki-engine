(function () {
  var samiURL = 'http://suika.fam.cx/www/js/sami/script/sami-core.js';
  
  var script = document.createElement ('script');
  script.src = samiURL;
  script.defer = true;
  script.async = true;
  document.body.appendChild (script);

  if (!self.SAMI) self.SAMI = {};
  SAMI.onLoadFunctions = SAMI.onLoadFunctions || [];
  SAMI.onLoadFunctions.push (function () {

  });
}) ();

window.onload = function () {
  createToolbar ();
  initializeHatenaStar();
  enableHTML5Support ();
}; // window.onload

function getElementsByClassName (c) {
  if (document.getElementsByClassName) {
    return document.getElementsByClassName (c);
  } else {
    return [];
  }
} // getElementsByClassName

function getAncestorElement (n, t) {
  while (n != null) {
    if (n.nodeName == t) {
      return n;
    } else {
      n = n.parentNode;
    }
  }
  return null;
} // getAncestorElement

function getGlobalDateAndTimeString (date) {
  var r = '';
  r = date.getUTCFullYear (); // JS does not support years 0001-0999
  r += '-' + ('0' + (date.getUTCMonth () + 1)).slice (-2);
  r += '-' + ('0' + date.getUTCDate ()).slice (-2);
  r += 'T' + ('0' + date.getUTCHours ()).slice (-2);
  r += ':' + ('0' + date.getUTCMinutes ()).slice (-2);
  r += ':' + ('0' + date.getUTCSeconds ()).slice (-2);
  r += '.' + (date.getUTCMilliseconds () + '00').slice (2);
  r += 'Z';
  return r;
} // getGlobalDateAndTimeString

function getNextAnchorNumber (s) {
  var lastId = 0;
  s.replace (/\[([0-9]+)\]/g, function (l, n) {
    var v = parseInt (n);
    if (v > lastId) {
      lastId = v;
    }
  });
  return lastId + 1;
} // getNextAnchorNumber

function createToolbar () {
  var containers = getElementsByClassName ('text-toolbar');
  for (var i = 0; i < containers.length; i++) {
    var container = containers[i];

    var form = getAncestorElement (container, 'FORM');
    var ta = form.elements.text;
    var insertText = function (added) {
      var st = ta.scrollTop;
      var ss = ta.selectionStart;
      var se = (ss != ta.selectionEnd);
      ta.value = ta.value.substring (0, ta.selectionStart)
          + added + ta.value.substring (ta.selectionEnd);
      if (se) {
        ta.setSelectionRange (ss, ss + added.length);
      } else {
        ta.setSelectionRange (ss + added.length, ss + added.length);
      }
      ta.scrollTop = st;
      ta.focus ();
    }; // insertText
    
    var addButton = function (labelHTML, title, onclick) {
      var button = document.createElement ('button');
      button.setAttribute ('type', 'button');
      button.innerHTML = labelHTML;
      button.title = title;
      button.onclick = onclick;
      container.appendChild (button);
    }; // addButton

    addButton ('[#]', 'Insert a new anchor number', function () {
      var added = '[' + getNextAnchorNumber (ta.value) + '] ';
      insertText (added);
    });

    addButton ('Now', 'Insert a timestamp', function () {
      var added = '[TIME[' + getGlobalDateAndTimeString (new Date) + ']]';
      insertText (added);
    });
  }
} // createToolbar

function initializeHatenaStar () {
  if (!window.Hatena) {
    window.Hatena = {};
  }
  if (!Hatena.Star) {
    Hatena.Star = {};
  }
  if (!Hatena.Star.onLoadFunctions) {
    Hatena.Star.onLoadFunctions = [];
  }

  Hatena.Star.onLoadFunctions.push (function () {
/*
    if (Ten.DOM.loaded) {
      Ten.DOM.loaded = false;
      Ten.DOM.addObserver ();
    }
*/

    Hatena.Star.SiteConfig = {
      entryNodes: {
        '' /* body */: {
          uri: 'h1 a',
          title: 'h1',
          container: '.tools' /* .nav.tools */
        }
      }
    };

/*
    var realLoadNewEntries = Hatena.Star.EntryLoader.loadNewEntries;
    Hatena.Star.EntryLoader.loadNewEntries = function (node) {
      if (!node) {
        node = document.documentElement;
      }
      realLoadNewEntries.apply (this, [node]);
    };
*/
    setTimeout (function () {
      Ten.DOM.dispatchEvent ('onload');
    }, 1);
  }); // Hatena.Star.onLoadFunctions.push'ed function

  var hsScript = document.createElement ('script');
  hsScript.defer = true;
  hsScript.src = 'http://s.hatena.ne.jp/js/HatenaStar.js';
  document.documentElement.lastChild.appendChild (hsScript);

  /*
    In SuikaWiki, a WikiName can be associated with multiple WikiPages, 
    while a WikiPage can be associated with multiple WikiNames.  It would
    be desired to associate Hatena Stars with WikiPages in theory.
    However, WikiPages do not have permalinks at the moment.

    See <http://suika.fam.cx/%7Ewakaba/wiki/sw/n/%E3%81%AF%E3%81%A6%E3%81%AA%E3%82%B9%E3%82%BF%E3%83%BC#anchor-2>.
  */
} // initializeHatenaStar

function enableHTML5Support () {
  window.TEROnLoad = function () {
    new TER.Delta (document.body);
  }; // window.TEROnLoad

  var timeScript = document.createElement ('script');
  timeScript.defer = true;
  timeScript.charset = 'utf-8';
  timeScript.src = 'http://suika.fam.cx/www/style/ui/time.js';
  document.documentElement.lastChild.appendChild (timeScript);
} // enableHTML5Support

/* Hack for IE */
document.createElement ('time');
