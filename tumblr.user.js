// ==UserScript==
// @name          tumblr name hider
// @grant       GM_getValue
// @grant       GM_setValue
// @description   hides blogs you've visited
// @include   http://*.tumblr.com/*
// ==/UserScript==

var host = window.location.host.split('.').shift();

GM_setValue(host, 1);

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
