window.onload = function () {
  createToolbar ();
}; // window.onload

function getElementsByClassName (c) {
  if (document.getElementsByClassName) {
    return document.getElementsByClassName (c);
  } else {

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
    button.type = 'button';
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