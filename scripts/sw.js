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

addEventListener ('DOMContentLoaded', function () {
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
  initFigures (document.body);
  addGoogleSearch ();
  enableHTML5Support ();
  addGoogleAnalytics ();
}); // DOMContentLoaded

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
  (function () {
    var _gaq = _gaq || [];
    _gaq.push (['_setAccount', 'UA-39820773-1']);
    _gaq.push (['_trackPageview']);
    window._gaq = _gaq;
    var ga = document.createElement ('script');
    ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    document.body.appendChild (ga);
  }) ();

  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-39820773-5', 'suikawiki.org');
  ga('send', 'pageview');
} // addGoogleAnalytics

/* Hack for IE */
document.createElement ('time');

if (!window.SW) window.SW = {};
if (!SW.Figure) SW.Figure = {};

SW.Figure.States = function (figure) {
/*
  This function derived from springyui.js
  <https://github.com/dhotson/springy/blob/master/springyui.js>.

Copyright (c) 2010 Dennis Hotson

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.

*/

  var ul = figure.getElementsByTagName ('ul')[0];
  if (!ul) return;
  var list = ul.children;

  var svg = document.createElementNS ('http://www.w3.org/2000/svg', 'svg');
  svg.innerHTML = '<defs><marker id="triangle" viewBox="0 0 10 10" refX="11" refY="5" markerWidth="6" markerHeight="6" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>';
  var svgDef = svg.firstChild;
  ul.parentNode.replaceChild (svg, ul);

  var graph = new Springy.Graph();
  var nodesByName = {};
  for (var i = 0; i < list.length; i++) {
    var item1 = list[i].firstElementChild;
    if (!item1) next;
    var item2 = item1.nextElementSibling;
    if (!nodesByName[item1.textContent]) {
      nodesByName[item1.textContent] = graph.newNode ({element: item1});
    }
    if (item2) {
      if (!nodesByName[item2.textContent]) {
        nodesByName[item2.textContent] = graph.newNode ({element: item2});
      }
      graph.newEdge (nodesByName[item1.textContent],
                     nodesByName[item2.textContent]);
    }
  }

  var layout = new Springy.Layout.ForceDirected (graph, 400, 400, 0.5);
  var currentBB = layout.getBoundingBox ();
  var targetBB = {bottomleft: new Springy.Vector (-2, -2),
                  topright: new Springy.Vector (2, 2)};
  Springy.requestAnimationFrame (function adjust () {
    targetBB = layout.getBoundingBox ();
    currentBB = {
      bottomleft: currentBB.bottomleft.add
                    (targetBB.bottomleft.subtract
                       (currentBB.bottomleft).divide (10)),
      topright: currentBB.topright.add
                    (targetBB.topright.subtract
                       (currentBB.topright).divide (10))
    };
    Springy.requestAnimationFrame (adjust);
  });
  var toScreen = function (p) {
    var size = currentBB.topright.subtract (currentBB.bottomleft);
    var sx = svg.offsetWidth * 0.05 + p.subtract (currentBB.bottomleft).divide (size.x).x * svg.offsetWidth * 0.9;
    var sy = svg.offsetHeight * 0.05 + p.subtract (currentBB.bottomleft).divide (size.y).y * svg.offsetHeight * 0.9;
    return new Springy.Vector (sx, sy);
  };
  var fromScreen = function (s) {
    var size = currentBB.topright.subtract (currentBB.bottomleft);
    var px = ((s.x - svg.offsetWidth * 0.05) / (svg.offsetWidth * 0.9)) * size.x + currentBB.bottomleft.x;
    var py = ((s.y - svg.offsetHeight * 0.05) / (svg.offsetHeight * 0.9)) * size.y + currentBB.bottomleft.y;
    return new Springy.Vector (px, py);
  };

  var textWidth = 10 * 16;
  var textHeight = 1 * 16;
  var lineHeight = 2.0;
  var renderer = new Springy.Renderer (
    layout,
    function clear () {
      svg.textContent = '';
      svg.appendChild (svgDef);
    },
    function drawEdge (edge, p1, p2) {
      var line = document.createElementNS (svg.namespaceURI, 'line');
      line.setAttribute ('class', 'edge');
      var s1 = toScreen (p1);
      var s2 = toScreen (p2);
      if (Math.abs (s2.y - s1.y) < textHeight * 4 &&
          ! (Math.abs (s2.x - s1.x) < textWidth * 1.0)) {
        if (s1.x < s2.x) {
          line.setAttribute ('x1', s1.x + textWidth / 2);
          line.setAttribute ('x2', s2.x - textWidth / 2);
        } else {
          line.setAttribute ('x1', s1.x - textWidth / 2);
          line.setAttribute ('x2', s2.x + textWidth / 2);
        }
        line.setAttribute ('y1', s1.y);
        line.setAttribute ('y2', s2.y);
      } else {
        line.setAttribute ('x1', s1.x);
        line.setAttribute ('x2', s2.x);
        if (s1.y < s2.y) {
          line.setAttribute ('y1', s1.y + textHeight * lineHeight / 2);
          line.setAttribute ('y2', s2.y - textHeight * lineHeight / 2);
        } else {
          line.setAttribute ('y1', s1.y - textHeight * lineHeight / 2);
          line.setAttribute ('y2', s2.y + textHeight * lineHeight / 2);
        }
      }
      svg.appendChild (line);
    },
    function drawNode (node, p) {
      var s = toScreen (p);
      var g = node.data.gElement || document.createElementNS (svg.namespaceURI, 'g');
      node.data.gElement = g;
      g.setAttribute ('class', 'node');
      var circle = g.querySelector ('rect') || document.createElementNS (svg.namespaceURI, 'rect');
      circle.setAttribute ('x', s.x - textWidth / 2);
      circle.setAttribute ('y', s.y - textHeight * lineHeight / 2);
      circle.setAttribute ('width', textWidth);
      circle.setAttribute ('height', textHeight * lineHeight);
      circle.setAttribute ('rx', 5);
      circle.setAttribute ('ry', 5);
      g.appendChild (circle);
      var text = g.querySelector ('foreignObject') || document.createElementNS (svg.namespaceURI, 'foreignObject');
      text.appendChild (node.data.element);
      text.setAttribute ('x', s.x - textWidth / 2);
      text.setAttribute ('y', s.y - textHeight / 2);
      text.setAttribute ('width', textWidth);
      text.setAttribute ('height', textHeight * 10);
      g.appendChild (text);
      svg.appendChild (g);
    }
  );

  var dragged = null;
  svg.onmousedown = function (ev) {
    var p = fromScreen ({x: ev.clientX - svg.offsetLeft, y: ev.clientY - svg.offsetTop});
    dragged = layout.nearest(p);
  };
  svg.onmousemove = function (ev) {
    var p = fromScreen ({x: ev.clientX - svg.offsetLeft, y: ev.clientY - svg.offsetTop});
    if (dragged !== null && dragged.node !== null) {
      dragged.point.p.x = p.x;
      dragged.point.p.y = p.y;
    }
    renderer.start();
  };
  window.addEventListener ('mouseup', function () { dragged = null });

  renderer.start();
}; // SW.Figure.States

SW.Figure.Railroad = function (figure) {
  var list = figure.querySelector ('ol, ul');
  if (!list) return;
  var svg = new SW.Figure.Railroad.Diagram (SW.Figure.Railroad.parseItems (list.children)).toSVG ();
  list.parentNode.replaceChild (svg, list);
}; // SW.Figure.Railroad

SW.Figure.Railroad.parseItems = function parseItems (list) {
  var items = Array.prototype.map.apply (list, [function (t) { return t }]);
  var elements = [];
  for (var i = 0; i < items.length; i++) {
    var li = items[i];
    if (li.lastChild.nodeType == li.TEXT_NODE &&
        li.lastChild.data.match (/^\s*$/)) {
      li.removeChild (li.lastChild);
    }
    if (li.childNodes.length == 2 &&
        li.firstChild.nodeType == li.TEXT_NODE &&
        li.lastChild.nodeType == li.ELEMENT_NODE &&
        li.lastChild.localName.match (/^[uo]l$/)) {
      var type = li.firstChild.data.replace (/\s+/g, '');
      if (type == '|') {
        var e = parseItems (li.lastChild.children);
        elements.push (new SW.Figure.Railroad.Choice (0, e));
        continue;
      } else if (type == '*' || type == '+') {
        var e = parseItems (li.lastChild.children);
        var f = {'*': SW.Figure.Railroad.ZeroOrMore, '+': SW.Figure.Railroad.OneOrMore}[type];
        elements.push (new f (new SW.Figure.Railroad.Sequence (e)));
        continue;
      } else if (type == '?') {
        var e = parseItems (li.lastChild.children);
        elements.push (new SW.Figure.Railroad.Optional (new SW.Figure.Railroad.Sequence (e)));
        continue;
      } else if (type == '=') {
        var e = parseItems (li.lastChild.children);
        elements.push (new SW.Figure.Railroad.Sequence (e));
        continue;
      } else {
        var e = parseItems (li.lastChild.children);
        elements.push (new SW.Figure.Railroad.Comment (type));
        elements.push (new SW.Figure.Railroad.Sequence (e));
        continue;
      }
    }
    var span = document.createElement ('span');
    span.innerHTML = li.innerHTML;
    document.body.appendChild (span); // for dimension
    elements.push (SW.Figure.Railroad.Terminal (span));
  }
  return elements;
}; // parseItems

function initFigures (root) {
  var figs = root.querySelectorAll ('figure.states');
  if (figs.length) {
    var script = document.createElement ('script');
    script.src = '/scripts/springy';
    script.onload = function () {
      for (var i = 0; i < figs.length; i++) {
        SW.Figure.States (figs[i]);
      }
    };
    document.body.appendChild (script);
  }

  var rfigs = root.querySelectorAll ('figure.railroad');
  if (rfigs.length) {
    var script = document.createElement ('script');
    script.src = '/scripts/railroad';
    script.onload = function () {
      for (var i = 0; i < rfigs.length; i++) {
        SW.Figure.Railroad (rfigs[i]);
      }
    };
    document.body.appendChild (script);
  }
} // initFigures

/* 

Copyright 2002-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

*/
