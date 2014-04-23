(function () {
  var samiURL = '/scripts/sami-core';
  var swSamiURL = '/scripts/sw-sami';
  
  var script = document.createElement ('script');
  script.src = samiURL;
  script.defer = true;
  script.async = true;
  document.body.appendChild (script);

  if (!self.SAMI) self.SAMI = {};
  SAMI.onLoadFunctions = SAMI.onLoadFunctions || [];
  SAMI.onLoadFunctions.push (function () {
    SAMI.Script.loadScripts (new SAMI.List([swSamiURL]), function () {
      SW.init ();
    });
  });
}) ();

window.onload = function () {
  document.write = function (html) {
    var div = document.createElement ('div');
    div.innerHTML = html;
    var scripts = div.getElementsByTagName ('script');
    var scriptsL = scripts.length;
    for (var i = 0; i < scriptsL; i++) {
      var oldScript = scripts[i];
      var script = document.createElement ('script');
      if (oldScript.src) script.src = oldScript.src;
      if (oldScript.charset) script.charset = oldScript.charset;
      if (oldScript.text) script.text = oldScript.text;
      div.appendChild (script);
    }
    document.body.appendChild (div);
  };

  createToolbar ();
  addGoogleSearch ();
  enableHTML5Support ();
  addGoogleAnalytics ();
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

function enableHTML5Support () {
  window.TEROnLoad = function () {
    new TER.Delta (document.body);
  }; // window.TEROnLoad

  var timeScript = document.createElement ('script');
  timeScript.defer = true;
  timeScript.charset = 'utf-8';
  timeScript.src = '/scripts/time';
  document.documentElement.lastChild.appendChild (timeScript);
} // enableHTML5Support

function addGoogleSearch () {
  var placeholder = document.getElementById ('cse-search-form');
  if (!placeholder) return;

  var script = document.createElement ('script');
  script.src = '//www.google.co.jp/jsapi';
  script.onload = function () {
    google.load('search', '1');
    setTimeout (function () {
    //google.setOnLoadCallback(function() {
      var customSearchControl = new google.search.CustomSearchControl('partner-pub-6943204637055835:1339232282');
      customSearchControl.setResultSetSize(google.search.Search.FILTERED_CSE_RESULTSET);
      var options = new google.search.DrawOptions();
      options.setAutoComplete(true);
      customSearchControl.draw('cse-search-form', options);
    //}, true);
    }, 1000);
  }; // onload
  document.body.appendChild (script);
} // addGoogleSearch

function addGoogleAnalytics () {
  var _gaq = _gaq || [];
  _gaq.push (['_setAccount', 'UA-39820773-1']);
  _gaq.push (['_trackPageview']);
  window._gaq = _gaq;
  var ga = document.createElement ('script');
  ga.async = true;
  ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
  document.body.appendChild (ga);

  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-39820773-5', 'suikawiki.org');
  ga('send', 'pageview');
} // addGoogleAnalytics

/* Hack for IE */
document.createElement ('time');

/* 

Copyright 2002-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

*/
