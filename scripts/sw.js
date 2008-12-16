window.onload = function () {
  createToolbar ();
  initializeHatenaStar();
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
    
    var button = document.createElement ('button');
    button.setAttribute ('type', 'button');
    button.innerHTML = '[#]';
    button.onclick = function () {
      var form = getAncestorElement (container, 'FORM');
      var ta = form.elements.text;
      var st = ta.scrollTop;
      var ss = ta.selectionStart;
      var se = (ss != ta.selectionEnd);
      var added = '[' + getNextAnchorNumber (ta.value) + '] ';
      /*
      if (ss > 0 && ta.value.substring (ss - 1, ss) != "\n") {
        added = "\n" + added;
      }
      */
      ta.value = ta.value.substring (0, ta.selectionStart)
          + added + ta.value.substring (ta.selectionEnd);
      if (se) {
        ta.setSelectionRange (ss, ss + added.length);
      } else {
        ta.setSelectionRange (ss + added.length, ss + added.length);
      }
      ta.scrollTop = st;
      ta.focus ();
    }; // button.onclick
    container.appendChild (button);
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
    if (Ten.DOM.loaded) {
      Ten.DOM.loaded = false;
      Ten.DOM.addObserver ();
    }

    Hatena.Star.SiteConfig = {
      entryNodes: {
        'body': {
          uri: 'h1 a',
          title: 'h1',
          container: '.tools' /* .nav.tools */
        }
      }
    };

    var realLoadNewEntries = Hatena.Star.EntryLoader.loadNewEntries;
    Hatena.Star.EntryLoader.loadNewEntries = function (node) {
      if (!node) {
        node = document.documentElement;
      }
      realLoadNewEntries.apply (this, [node]);
    };

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
  */
} // initializeHatenaStar
