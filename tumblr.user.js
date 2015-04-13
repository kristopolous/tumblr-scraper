// ==UserScript==
// @name          tumblr name hider
// @grant       GM_getValue
// @grant       GM_setValue
// @grant       GM_xmlhttpRequest
// @description   hides blogs you've visited
// @include   http://*.tumblr.com/*
// ==/UserScript==

var host = window.location.host.split('.').shift();

// see if we've banashed this host before
var exist = GM_getValue(host);

if(!exist) {
  // see if we have the last id recorded
  var last = GM_getValue('__last');
  if(!last) {
    last = 0;
  }
  
  // if we haven't then we add it here
  // and remotely!
  GM_setValue(host, 1);
  GM_xmlhttpRequest({
    method: 'GET',
    url: 'http://10.0.0.1/blacklist.php?last=' + last + '&urlList[]=' + host,
    onload: function(response) {
      var json = JSON.parse(response.responseText);
      for(var i = 0; i < json.url.length; i++) {
        GM_setValue(json.url[i], 1);
      }
      GM_setValue('__last', json.last);
    }
  });
}

function hider() {

  var linkList = document.getElementsByTagName('a'), 
      link;

  for(var i = 0; i < linkList.length; i++) {
    link = linkList[i];

    if(GM_getValue(link.innerHTML)) {
      link.style.opacity = 0;
    } 
  }
}

hider();
setInterval(hider, 10000);

